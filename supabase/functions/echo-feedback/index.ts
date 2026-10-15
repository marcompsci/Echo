// Echo — feedback → GitHub (Supabase Edge Function)
//
// User feedback:      committed as feedback/users/<date>-<slug>.md
// Developer feedback: Echo (Claude) rewrites it into a clear change request,
//                     then commits feedback/developers/<date>-<slug>.md with a
//                     commit message written as a to-do comment for the app's
//                     developer. Developers must be signed in with GitHub.
//
// Everything lands on a separate branch (default: echo-feedback) so it never
// touches the app's main code.
//
// Secrets:
//   GITHUB_TOKEN      required  fine-grained token, Contents: Read & write on the repo
//   GITHUB_REPO       optional  default "marcompsci/Echo"
//   FEEDBACK_BRANCH   optional  default "echo-feedback"
//   ANTHROPIC_API_KEY optional  used to write developer change requests (falls back to raw text)
//   ECHO_FEEDBACK_MODEL optional default "claude-haiku-5-5"
// Deploy with --no-verify-jwt (the app sends its publishable key on "apikey").

const MAX_MESSAGE = 4000;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function publishableKeys(): string[] {
  const keys: string[] = [];
  const many = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (many) { try { keys.push(...Object.values(JSON.parse(many) as Record<string, string>)); } catch { /* ignore */ } }
  for (const n of ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"]) { const v = Deno.env.get(n); if (v) keys.push(v); }
  return keys.filter(Boolean);
}

function slugify(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 48) || "feedback";
}

function b64(text: string): string {
  const bytes = new TextEncoder().encode(text);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

/** Looks up the signed-in Supabase user (to confirm GitHub developers). */
async function getUser(token: string | null): Promise<Record<string, any> | null> {
  if (!token) return null;
  const base = Deno.env.get("SUPABASE_URL");
  const key = publishableKeys()[0] ?? Deno.env.get("SUPABASE_ANON_KEY");
  if (!base || !key) return null;
  const res = await fetch(`${base}/auth/v1/user`, { headers: { apikey: key, Authorization: `Bearer ${token}` } });
  return res.ok ? await res.json() : null;
}

interface ChangeRequest { title: string; comment: string; details: string; }

/** Claude rewrites developer feedback as a short, actionable change request. */
async function writeChangeRequest(message: string, area: string): Promise<ChangeRequest> {
  const fallback = { title: message.split("\n")[0].slice(0, 70), comment: `TODO: ${message.slice(0, 200)}`, details: message };
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return fallback;
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: Deno.env.get("ECHO_FEEDBACK_MODEL") || "claude-haiku-5-5",
        max_tokens: 700,
        system: "You turn developer feedback about the Echo iOS app into a clear change request for the app's developer. Be concrete and brief. Don't invent file names.",
        tools: [{
          name: "change_request",
          description: "A change request for the Echo app.",
          input_schema: {
            type: "object",
            properties: {
              title: { type: "string", description: "Imperative, under 70 characters, e.g. 'Make Live Guide banners shorter'." },
              comment: { type: "string", description: "One or two sentences written as a TODO comment to the developer: what to change and why." },
              details: { type: "string", description: "Markdown: Problem, Suggested change, How to verify." },
            },
            required: ["title", "comment", "details"],
          },
        }],
        tool_choice: { type: "tool", name: "change_request" },
        messages: [{ role: "user", content: `Area of the app: ${area}\n\nDeveloper feedback:\n${message}` }],
      }),
    });
    if (!res.ok) return fallback;
    const data = await res.json();
    const input = (data.content ?? []).find((c: any) => c.type === "tool_use")?.input;
    if (!input?.title) return fallback;
    return { title: String(input.title).slice(0, 70), comment: String(input.comment ?? ""), details: String(input.details ?? "") };
  } catch {
    return fallback;
  }
}

async function github(path: string, init: RequestInit = {}) {
  const token = Deno.env.get("GITHUB_TOKEN")!;
  return await fetch(`https://api.github.com${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

/** Makes sure the feedback branch exists (created from the default branch). */
async function ensureBranch(repo: string, branch: string) {
  const existing = await github(`/repos/${repo}/git/ref/heads/${branch}`);
  if (existing.ok) return;
  const repoInfo = await (await github(`/repos/${repo}`)).json();
  const base = await (await github(`/repos/${repo}/git/ref/heads/${repoInfo.default_branch}`)).json();
  const created = await github(`/repos/${repo}/git/refs`, {
    method: "POST",
    body: JSON.stringify({ ref: `refs/heads/${branch}`, sha: base.object.sha }),
  });
  if (!created.ok && created.status !== 422) throw new Error(`branch ${created.status}`);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const allowed = publishableKeys();
  if (allowed.length && !allowed.includes(req.headers.get("apikey") ?? "")) {
    return json({ error: "Missing or invalid apikey." }, 401);
  }
  if (!Deno.env.get("GITHUB_TOKEN")) return json({ error: "Feedback isn't set up yet (missing GITHUB_TOKEN)." }, 503);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Body must be JSON." }, 400); }
  const kind = body?.kind === "developer" ? "developer" : "user";
  const message = String(body?.message ?? "").trim();
  const category = String(body?.category ?? "General").slice(0, 40);
  if (message.length < 5) return json({ error: "Please write a little more." }, 400);
  if (message.length > MAX_MESSAGE) return json({ error: "That's too long — keep it under 4,000 characters." }, 413);

  const user = await getUser(req.headers.get("x-echo-user-token"));
  const meta = user?.user_metadata ?? {};
  const provider = user?.app_metadata?.provider;
  const githubLogin: string | null = provider === "github" ? (meta.user_name ?? meta.preferred_username ?? null) : null;

  if (kind === "developer" && !githubLogin) {
    return json({ error: "Connect your GitHub account in Echo to send developer feedback." }, 403);
  }

  const repo = Deno.env.get("GITHUB_REPO") || "marcompsci/Echo";
  const branch = Deno.env.get("FEEDBACK_BRANCH") || "echo-feedback";
  const now = new Date();
  const date = now.toISOString().slice(0, 10);
  const device = `${body?.device ?? "iPhone"} · iOS ${body?.osVersion ?? "?"} · Echo ${body?.appVersion ?? "?"}`;

  let path: string, commitMessage: string, file: string, title: string;

  if (kind === "developer") {
    const cr = await writeChangeRequest(message, category);
    title = cr.title;
    path = `feedback/developers/${date}-${slugify(cr.title)}-${now.getTime() % 100000}.md`;
    commitMessage = `Feedback: ${cr.title}\n\n// TODO(Omari): ${cr.comment}\n\nArea: ${category}\nFrom: @${githubLogin}\nWritten by Echo from developer feedback.`;
    file = `# ${cr.title}\n\n> // TODO(Omari): ${cr.comment}\n\n- **Area:** ${category}\n- **From:** @${githubLogin}\n- **Device:** ${device}\n- **Date:** ${now.toISOString()}\n\n${cr.details}\n\n---\n\n<details><summary>Original feedback</summary>\n\n${message}\n\n</details>\n`;
  } else {
    title = `${category}: ${message.split("\n")[0].slice(0, 60)}`;
    path = `feedback/users/${date}-${slugify(message.slice(0, 40))}-${now.getTime() % 100000}.md`;
    commitMessage = `User feedback (${category}): ${message.split("\n")[0].slice(0, 60)}`;
    const who = meta.full_name ?? meta.name ?? (user?.email ? "signed-in user" : "anonymous");
    file = `# ${category}\n\n- **From:** ${who}\n- **Device:** ${device}\n- **Date:** ${now.toISOString()}\n\n${message}\n`;
  }

  try {
    await ensureBranch(repo, branch);
    const put = await github(`/repos/${repo}/contents/${path}`, {
      method: "PUT",
      body: JSON.stringify({ message: commitMessage, content: b64(file), branch }),
    });
    if (!put.ok) {
      console.error("GitHub commit failed", put.status, (await put.text()).slice(0, 300));
      return json({ error: "Couldn't save feedback to GitHub." }, 502);
    }
    const out = await put.json();
    console.log(`feedback ok kind=${kind} path=${path}`);
    return json({ title, url: out?.commit?.html_url ?? null });
  } catch (err) {
    console.error("feedback error", (err as Error).message);
    return json({ error: "Couldn't save feedback to GitHub." }, 502);
  }
});
