import Foundation
import Contacts

// MARK: - Contact operations using CNContactStore

actor ContactAgent {
    private let store = CNContactStore()

    // MARK: - Permission

    func requestAccess() async -> Bool {
        let current = CNContactStore.authorizationStatus(for: .contacts)
        if current == .authorized { return true }
        if current == .denied || current == .restricted { return false }
        return await withCheckedContinuation { cont in
            store.requestAccess(for: .contacts) { granted, _ in
                cont.resume(returning: granted)
            }
        }
    }

    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    // MARK: - Fetch

    func fetchAll() async throws -> [CNContact] {
        guard await requestAccess() else {
            throw EchoError.permissionDenied(.contacts)
        }
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var results: [CNContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            results.append(contact)
        }
        return results
    }

    func search(query: String) async throws -> [CNContact] {
        let all = try await fetchAll()
        let q = query.lowercased()
        return all.filter { c in
            c.givenName.lowercased().contains(q) ||
            c.familyName.lowercased().contains(q) ||
            c.phoneNumbers.contains { $0.value.stringValue.contains(q) }
        }
    }

    // MARK: - Mutate

    func delete(contactWithID id: String) async throws {
        guard await requestAccess() else {
            throw EchoError.permissionDenied(.contacts)
        }
        let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor]
        let mutable = try store.unifiedContact(withIdentifier: id, keysToFetch: keys).mutableCopy() as! CNMutableContact
        let request = CNSaveRequest()
        request.delete(mutable)
        try store.execute(request)
    }

    func create(givenName: String, familyName: String, phone: String?) async throws {
        guard await requestAccess() else {
            throw EchoError.permissionDenied(.contacts)
        }
        let contact = CNMutableContact()
        contact.givenName = givenName
        contact.familyName = familyName
        if let phone {
            contact.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMain,
                               value: CNPhoneNumber(stringValue: phone))
            ]
        }
        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        try store.execute(request)
    }
}
