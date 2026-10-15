// Echo — guide backend (Supabase Edge Function)
//
// Receives a screenshot + question from the iOS app, asks Claude to explain
// the screen, and returns a GuideResponse JSON that the app decodes directly.
//
// The app also sends the text it found on the screen (on-device OCR) with
// exact bounding boxes. Claude points at those element IDs, so the numbered
// markers land precisely on the right button instead of a rough guess.
//
// Secrets (set with `supabase secrets set ...`):
//   ANTHROPIC_API_KEY   required
//   ECHO_MODEL          optional, defaults to claude-sonnet-5-5
//
// Privacy: the image is never logged or stored. Only status + timing are logged.

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const DEFAULT_MODEL = "claude-sonnet-5-5";
const MAX_IMAGE_BASE64_CHARS = 7_000_000; // ~5 MB image
const MAX_QUESTION_CHARS = 600;
const MAX_ELEMENTS = 200;

// ---------- Types: request from the app ----------

interface ScreenElement {
  id: string;
  text: string;
  x: number; // 0–1, top-left origin
  y: number;
  width: number;
  height: number;
}

interface GuideRequest {
  imageBase64: string;
  mediaType?: string;
  userQuestion: string;
  deviceLocale?: string;
  appVersion?: string;
  imageWidth?: number;
  imageHeight?: number;
  elements?: ScreenElement[];
  // Live Guide (broadcast extension) fields
  mode?: "guide" | "live";
  goal?: string;
  history?: string[];
}

// ---------- Types: what Claude fills in ----------

interface ClaudeMarker {
  step_number: number;
  element_id?: string;
  box?: { x: number; y: number; width: number; height: number };
  shape?: "circle" | "roundedRectangle";
  caution?: boolean;
}

interface ClaudeGuide {
  summary: string;
  safety_notice?: string | null;
  steps: { number: number; title: string; detail: string }[];
  markers: ClaudeMarker[];
  action_suggestions?: { type: string; title: string; subtitle: string }[];
}

// ---------- Prompt + tool schema ----------

const SYSTEM_PROMPT = `You are Echo, a calm, patient helper inside an iPhone app.
People send you a screenshot of their phone and a question. Many of them are not tech-savvy.

How to answer:
- Look at the screenshot and the question. Figure out what the person is trying to do.
- Give a one or two sentence summary in plain, friendly language. No jargon.
- Give 1 to 5 short numbered steps. Each step is one action ("Tap Settings", "Scroll down to Wi-Fi").
- For each step that involves something visible on THIS screen, add a marker with the same step_number.
  - If the thing to tap matches one of the listed on-screen text elements, set element_id to that element's id. Prefer this whenever possible — it is exact.
  - Otherwise (icons, toggles, images with no text), set box to your best estimate of its location as fractions of the image: x and y are the TOP-LEFT corner, width and height are sizes, all between 0 and 1.
  - Steps that happen on a later screen get no marker.
- Use shape "circle" for small icons/toggles and "roundedRectangle" for buttons, rows, and text.
- Never invent buttons that are not there. If the screen doesn't let them do what they want, say so and tell them where to go instead.

Safety:
- If the screen looks like a scam, phishing, a fake virus warning, a suspicious payment or gift-card request, or asks for a password/code someone sent them, put a short clear warning in safety_notice and mark the risky element with caution: true.
- Never tell someone to share a password, verification code, or card number.
- If there is nothing risky, set safety_notice to null.

Language: reply in the language of the user's question (device locale given as a hint).
Always answer by calling the create_guide tool.`;

const GUIDE_TOOL = {
  name: "create_guide",
  description: "Return the guide for the user's screenshot and question.",
  input_schema: {
    type: "object",
    properties: {
      summary: { type: "string", description: "1–2 plain-language sentences." },
      safety_notice: {
        type: ["string", "null"],
        description: "Short warning if anything on screen is risky, else null.",
      },
      steps: {
        type: "array",
        minItems: 1,
        maxItems: 5,
        items: {
          type: "object",
          properties: {
            number: { type: "integer" },
            title: { type: "string", description: "Short action, e.g. 'Tap Wi-Fi'." },
            detail: { type: "string", description: "One sentence of extra help." },
          },
          required: ["number", "title", "detail"],
        },
      },
      markers: {
        type: "array",
        maxItems: 6,
        items: {
          type: "object",
          properties: {
            step_number: { type: "integer" },
            element_id: { type: "string", description: "ID of a listed on-screen text element." },
            box: {
              type: "object",
              properties: {
                x: { type: "number" },
                y: { type: "number" },
                width: { type: "number" },
                height: { type: "number" },
              },
              required: ["x", "y", "width", "height"],
            },
            shape: { type: "string", enum: ["circle", "roundedRectangle"] },
            caution: { type: "boolean" },
          },
          required: ["step_number"],
        },
      },
      action_suggestions: {
        type: "array",
        maxItems: 3,
        items: {
          type: "object",
          properties: {
            type: {
              type: "string",
              enum: ["openSettings", "createReminder", "createNote", "openMaps", "copyText", "shareGuide"],
            },
            title: { type: "string" },
            subtitle: { type: "string" },
          },
          required: ["type", "title", "subtitle"],
        },
      },
    },
    required: ["summary", "safety_notice", "steps", "markers"],
  },
};

// ---------- Mapping Claude's answer → the app's GuideResponse ----------

const ACTION_ICONS: Record<string, string> = {
  openSettings: "gear",
  createReminder: "bell.badge",
  createNote: "note.text",
  openMaps: "map",
  copyText: "doc.on.doc",
  shareGuide: "square.and.arrow.up",
};

const clamp01 = (n: number) => Math.min(1, Math.max(0, Number.isFinite(n) ? n : 0));

function toAnnotation(marker: ClaudeMarker, elements: Map<string, ScreenElement>) {
  let box = marker.element_id ? elements.get(marker.element_id) : undefined;
  let source: { x: number; y: number; width: number; height: number } | undefined = box ?? marker.box;
  if (!source) return null;

  // Pad exact OCR boxes a little so the outline sits around the text, not on it.
  const pad = box ? 0.012 : 0;
  let x = clamp01(source.x - pad);
  let y = clamp01(source.y - pad);
  let w = clamp01(source.width + pad * 2);
  let h = clamp01(source.height + pad * 2);
  if (x + w > 1) w = 1 - x;
  if (y + h > 1) h = 1 - y;
  if (w < 0.01 || h < 0.005) return null;

  return {
    id: crypto.randomUUID(),
    type: marker.shape === "circle" ? "circle" : "roundedRectangle",
    normalizedX: x,
    normalizedY: y,
    normalizedWidth: w,
    normalizedHeight: h,
    label: String(marker.step_number),
    colorStyle: marker.caution ? "warning" : "accent",
  };
}

function toGuideResponse(guide: ClaudeGuide, elements: ScreenElement[]) {
  const byId = new Map(elements.map((e) => [e.id, e]));
  const steps = (guide.steps ?? []).slice(0, 5).map((s, i) => ({
    id: crypto.randomUUID(),
    number: Number.isInteger(s.number) ? s.number : i + 1,
    title: String(s.title ?? "").slice(0, 120),
    detail: String(s.detail ?? "").slice(0, 400),
  }));
  const annotations = (guide.markers ?? [])
    .map((m) => toAnnotation(m, byId))
    .filter((a) => a !== null);
  const actionSuggestions = (guide.action_suggestions ?? [])
    .filter((a) => a.type in ACTION_ICONS)
    .slice(0, 3)
    .map((a) => ({
      id: crypto.randomUUID(),
      title: String(a.title).slice(0, 80),
      subtitle: String(a.subtitle).slice(0, 160),
      systemImage: ACTION_ICONS[a.type],
      actionType: a.type,
      requiresConfirmation: a.type !== "shareGuide" && a.type !== "copyText",
    }));

  return {
    id: crypto.randomUUID(),
    summary: String(guide.summary ?? "").slice(0, 600),
    safetyNotice: guide.safety_notice ? String(guide.safety_notice).slice(0, 300) : null,
    steps,
    annotations,
    actionSuggestions,
  };
}

// ---------- Helpers ----------

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function validate(body: unknown): GuideRequest | string {
  if (!body || typeof body !== "object") return "Body must be JSON.";
  const b = body as GuideRequest;
  if (typeof b.imageBase64 !== "string" || b.imageBase64.length < 100) return "imageBase64 is required.";
  if (b.imageBase64.length > MAX_IMAGE_BASE64_CHARS) return "Image is too large.";
  if (typeof b.userQuestion !== "string" || !b.userQuestion.trim()) return "userQuestion is required.";
  if (b.userQuestion.length > MAX_QUESTION_CHARS) return "Question is too long.";
  if (b.mediaType && !["image/jpeg", "image/png"].includes(b.mediaType)) return "Unsupported image type.";
  if (b.elements && !Array.isArray(b.elements)) return "elements must be an array.";
  return b;
}

function describeElements(elements: ScreenElement[]): string {
  if (!elements.length) return "No on-screen text was detected.";
  const lines = elements.map((e) =>
    `${e.id}: "${e.text.replace(/\s+/g, " ").slice(0, 80)}" at x=${e.x.toFixed(3)} y=${e.y.toFixed(3)} w=${e.width.toFixed(3)} h=${e.height.toFixed(3)}`
  );
  return `On-screen text elements (top-left origin, fractions of the image):\n${lines.join("\n")}`;
}

// The app sends the project's publishable key on the "apikey" header.
// Deploy with --no-verify-jwt (publishable keys are not JWTs); this check
// rejects callers that don't have the key. Supabase injects the keys as env vars.
function publishableKeys(): string[] {
  const keys: string[] = [];
  const many = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (many) {
    try {
      keys.push(...Object.values(JSON.parse(many) as Record<string, string>));
    } catch { /* ignore malformed */ }
  }
  for (const name of ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"]) {
    const v = Deno.env.get(name);
    if (v) keys.push(v);
  }
  return keys.filter(Boolean);
}

function isAuthorized(req: Request): boolean {
  const allowed = publishableKeys();
  if (!allowed.length) {
    console.warn("No publishable keys in env; skipping apikey check");
    return true;
  }
  const sent = req.headers.get("apikey") ??
    req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  return allowed.includes(sent);
}

// ---------- Live Guide mode ----------
//
// Called ~every time the person's screen settles on something new while they
// share their screen with Echo. Answers: "on THIS screen, what's the single next
// thing to do toward the goal?" Short, spoken-friendly, fast model by default.

const LIVE_SYSTEM_PROMPT = `You are Echo, coaching someone live through a task on their iPhone.
You see their current screen. They told you their goal. You also get the steps you already gave.

Reply with exactly one thing for them to do next on THIS screen, in plain words a non-technical person understands.
- status "next_step": the next action on this screen ("Tap Display & Brightness, about halfway down").
- status "wrong_screen": they're somewhere that doesn't lead to the goal; tell them how to get back on track.
- status "waiting": the screen is loading, a transition, the lock screen, or Echo's own app — nothing to say yet.
- status "done": the goal is clearly finished on this screen; congratulate them in one short sentence.
Rules:
- instruction: max ~12 words, starts with a verb, names the exact button text and roughly where it is.
- detail: one short extra sentence, or empty.
- Don't repeat a step they've already done unless the screen shows it wasn't done.
- If the screen looks like a scam, phishing, or asks them to share a password, code, gift card, or payment with someone, set safety_notice and tell them to stop.
- Never tell them to type a password or code for you.
Always answer with the next_step tool.`;

const LIVE_TOOL = {
  name: "next_step",
  description: "The single next step toward the person's goal on the current screen.",
  input_schema: {
    type: "object",
    properties: {
      status: { type: "string", enum: ["next_step", "wrong_screen", "waiting", "done"] },
      instruction: { type: "string" },
      detail: { type: "string" },
      safety_notice: { type: ["string", "null"] },
    },
    required: ["status", "instruction", "detail", "safety_notice"],
  },
};

async function handleLive(request: GuideRequest, apiKey: string): Promise<Response> {
  const goal = (request.goal ?? request.userQuestion ?? "").trim().slice(0, MAX_QUESTION_CHARS);
  if (!goal) return json({ error: "goal is required." }, 400);
  const history = (Array.isArray(request.history) ? request.history : [])
    .filter((h) => typeof h === "string")
    .slice(-8)
    .map((h, i) => `${i + 1}. ${h.slice(0, 160)}`);
  const model = Deno.env.get("ECHO_LIVE_MODEL") || Deno.env.get("ECHO_MODEL") || "claude-haiku-5-5";
  const started = Date.now();

  let res: Response;
  try {
    res = await fetch(ANTHROPIC_URL, {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model,
        max_tokens: 400,
        system: LIVE_SYSTEM_PROMPT,
        tools: [LIVE_TOOL],
        tool_choice: { type: "tool", name: "next_step" },
        messages: [{
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: request.mediaType ?? "image/jpeg", data: request.imageBase64 } },
            {
              type: "text",
              text: [
                `Goal: ${goal}`,
                history.length ? `Steps already given:\n${history.join("\n")}` : "No steps given yet.",
                `Device locale: ${request.deviceLocale ?? "unknown"}`,
              ].join("\n\n"),
            },
          ],
        }],
      }),
    });
  } catch (err) {
    console.error("Claude live request failed:", (err as Error).message);
    return json({ error: "Guide service is unavailable." }, 503);
  }
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    console.error(`Claude live error ${res.status}: ${detail.slice(0, 300)}`);
    return json({ error: "Guide service is busy. Try again." }, res.status === 429 ? 429 : 503);
  }
  const data = await res.json();
  const tool = (data.content ?? []).find((c: { type: string; name?: string }) => c.type === "tool_use" && c.name === "next_step");
  const input = tool?.input as { status?: string; instruction?: string; detail?: string; safety_notice?: string | null } | undefined;
  if (!input) return json({ error: "Guide service returned an unexpected answer." }, 503);

  const allowed = ["next_step", "wrong_screen", "waiting", "done"];
  const reply = {
    status: allowed.includes(input.status ?? "") ? input.status : "waiting",
    instruction: String(input.instruction ?? "").slice(0, 160),
    detail: String(input.detail ?? "").slice(0, 240),
    safetyNotice: input.safety_notice ? String(input.safety_notice).slice(0, 200) : null,
  };
  console.log(`live ok model=${model} ms=${Date.now() - started} status=${reply.status}`);
  return json(reply);
}

// ---------- Handler ----------

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);
  if (!isAuthorized(req)) return json({ error: "Missing or invalid apikey." }, 401);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY is not set");
    return json({ error: "Guide service is not configured." }, 503);
  }

  let parsed: GuideRequest | string;
  try {
    parsed = validate(await req.json());
  } catch {
    parsed = "Body must be JSON.";
  }
  if (typeof parsed === "string") return json({ error: parsed }, parsed.includes("too large") ? 413 : 400);
  const request = parsed;
  if (request.mode === "live") return await handleLive(request, apiKey);

  const elements = (request.elements ?? [])
    .slice(0, MAX_ELEMENTS)
    .filter((e) => e && typeof e.id === "string" && typeof e.text === "string")
    .map((e) => ({
      id: e.id,
      text: e.text,
      x: clamp01(e.x),
      y: clamp01(e.y),
      width: clamp01(e.width),
      height: clamp01(e.height),
    }));

  const started = Date.now();
  const model = Deno.env.get("ECHO_MODEL") || DEFAULT_MODEL;

  let claudeRes: Response;
  try {
    claudeRes = await fetch(ANTHROPIC_URL, {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model,
        max_tokens: 1500,
        system: SYSTEM_PROMPT,
        tools: [GUIDE_TOOL],
        tool_choice: { type: "tool", name: "create_guide" },
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: request.mediaType ?? "image/jpeg",
                  data: request.imageBase64,
                },
              },
              {
                type: "text",
                text: [
                  `Question: ${request.userQuestion.trim()}`,
                  `Device locale: ${request.deviceLocale ?? "unknown"}`,
                  request.imageWidth && request.imageHeight
                    ? `Image size: ${request.imageWidth}x${request.imageHeight} px`
                    : "",
                  describeElements(elements),
                ].filter(Boolean).join("\n\n"),
              },
            ],
          },
        ],
      }),
    });
  } catch (err) {
    console.error("Claude request failed:", (err as Error).message);
    return json({ error: "Guide service is unavailable." }, 503);
  }

  if (!claudeRes.ok) {
    const detail = await claudeRes.text().catch(() => "");
    console.error(`Claude error ${claudeRes.status}: ${detail.slice(0, 300)}`);
    const status = claudeRes.status === 429 ? 429 : 503;
    return json({ error: "Guide service is busy. Try again." }, status);
  }

  const data = await claudeRes.json();
  const toolUse = (data.content ?? []).find(
    (c: { type: string; name?: string }) => c.type === "tool_use" && c.name === "create_guide",
  );
  if (!toolUse?.input) {
    console.error("Claude returned no guide");
    return json({ error: "Guide service returned an unexpected answer." }, 503);
  }

  const response = toGuideResponse(toolUse.input as ClaudeGuide, elements);
  console.log(
    `guide ok model=${model} ms=${Date.now() - started} steps=${response.steps.length} markers=${response.annotations.length} elements=${elements.length}`,
  );
  return json(response);
});
