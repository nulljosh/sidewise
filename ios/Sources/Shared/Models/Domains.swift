import Foundation

/// The site part of a host: `www.nypost.com` and `nypost.com` are the same, `news.bbc.co.uk` is `bbc.co.uk`.
func registrableDomain(_ host: String) -> String {
    let labels = host.lowercased().split(separator: ".").map(String.init)
    guard labels.count > 2 else { return labels.joined(separator: ".") }
    let secondLevel: Set<String> = ["co", "com", "org", "net", "gov", "ac"]
    let n = (labels.last!.count == 2 && secondLevel.contains(labels[labels.count - 2])) ? 3 : 2
    return labels.suffix(n).joined(separator: ".")
}

/// The name part of a domain: `bbc.co.uk` and `bbc.com` both give `bbc`.
func domainStem(_ domain: String) -> String {
    domain.split(separator: ".").first.map(String.init) ?? domain
}

/// Matches an article link to a rated outlet. It learns each outlet's domains from the links the
/// feed actually carries, so nothing is guessed. An outlet that links all over the web (an
/// aggregator such as Hacker News) is left out, and a domain two outlets claim is ambiguous and
/// matches nothing.
struct DomainIndex {
    private var byDomain: [String: Source] = [:]
    private var byStem: [String: Source] = [:]

    init(_ sources: [Source], aggregatorThreshold: Int = 6) {
        var domains: [String: Set<String>] = [:]      // outlet -> domains
        var owners: [String: Set<String>] = [:]       // domain -> outlets
        var sample: [String: Source] = [:]            // outlet -> one source, for the rating
        for s in sources {
            guard let host = s.url?.host else { continue }
            let d = registrableDomain(host)
            domains[s.outletKey, default: []].insert(d)
            owners[d, default: []].insert(s.outletKey)
            sample[s.outletKey] = sample[s.outletKey] ?? s
        }
        for (domain, outlets) in owners where outlets.count == 1 {
            let outlet = outlets.first!
            guard (domains[outlet]?.count ?? 0) <= aggregatorThreshold, let s = sample[outlet] else { continue }
            byDomain[domain] = s
        }
        // The same newsroom often runs two domains (bbc.co.uk and bbc.com). Match on the name when
        // exactly one outlet owns it.
        var stemOwners: [String: Set<String>] = [:]
        for (domain, s) in byDomain { stemOwners[domainStem(domain), default: []].insert(s.outletKey) }
        for (domain, s) in byDomain where stemOwners[domainStem(domain)]?.count == 1 {
            byStem[domainStem(domain)] = s
        }
    }

    /// The rated outlet for this link, or nil when the outlet is not one Sidewise rates.
    func outlet(for url: URL) -> Source? {
        guard let host = url.host else { return nil }
        let domain = registrableDomain(host)
        return byDomain[domain] ?? byStem[domainStem(domain)]
    }
}
