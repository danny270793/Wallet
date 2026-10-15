import SwiftUI

/// About, privacy policy and terms of use.
struct LegalView: View {
  enum Kind { case about, privacy, terms }
  let kind: Kind

  private var version: String {
    let i = Bundle.main.infoDictionary
    return "\(i?["CFBundleShortVersionString"] as? String ?? "?") (\(i?["CFBundleVersion"] as? String ?? "?"))"
  }

  var body: some View {
    List {
      switch kind {
      case .about:
        Section {
          VStack(spacing: 10) {
            Image("AppIconImage").resizable().frame(width: 84, height: 84).clipShape(.rect(cornerRadius: 19))
            Text(L("appTitle")).font(.title2.bold())
            Text(L("settingsAboutTagline")).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
          LabeledContent(L("settingsAboutVersionLabel"), value: version)
        }
        Section(L("settingsAboutFeaturesHeading")) {
          Label(L("settingsAboutBulletAccounts"), systemImage: "building.columns")
          Label(L("settingsAboutBulletLedger"), systemImage: "list.bullet.rectangle")
          Label(L("settingsAboutBulletMonth"), systemImage: "calendar")
        }
        Section(L("settingsAboutDataHeading")) { Text(L("settingsAboutDataBody")) }
        Section(L("settingsAboutDeveloperHeading")) {
          Link(L("settingsAboutDeveloperGithub"), destination: URL(string: "https://github.com/danny270793")!)
          Link(L("settingsAboutDeveloperWebsite"), destination: URL(string: "https://danny270793.github.io/")!)
          Link(L("settingsAboutDeveloperYoutube"), destination: URL(string: "https://www.youtube.com/channel/UC5MAQWU2s2VESTXaUo-ysgg")!)
          Link(L("settingsAboutDeveloperLinkedin"), destination: URL(string: "https://www.linkedin.com/in/danny270793/")!)
        }
      case .privacy:
        Section { Text(L("settingsPrivacyTagline")).foregroundStyle(.secondary) }
        block("settingsPrivacyDataTitle", "settingsPrivacyDataBody")
        block("settingsPrivacyInfraTitle", "settingsPrivacyInfraBody")
        block("settingsPrivacySharingTitle", "settingsPrivacySharingBody")
        block("settingsPrivacyNoticeTitle", "settingsPrivacyNoticeBody")
      case .terms:
        Section { Text(L("settingsTermsTagline")).foregroundStyle(.secondary) }
        block("settingsTermsAcceptanceTitle", "settingsTermsAcceptanceBody")
        block("settingsTermsDisclaimerTitle", "settingsTermsDisclaimerBody")
        block("settingsTermsLiabilityTitle", "settingsTermsLiabilityBody")
        block("settingsTermsResponsibilitiesTitle", "settingsTermsResponsibilitiesBody")
        block("settingsTermsNoticeTitle", "settingsTermsNoticeBody")
      }
    }
    .navigationTitle(L(kind == .about ? "settingsAboutApp" : kind == .privacy ? "settingsPrivacyPolicy" : "settingsTermsOfUse"))
  }

  private func block(_ title: String, _ body: String) -> some View {
    Section(L(title)) { Text(L(body)) }
  }
}
