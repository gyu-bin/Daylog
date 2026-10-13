import AuthenticationServices
import CryptoKit
import SwiftUI

/// 템플릿 공유용 로그인 상태와 로그인·로그아웃·계정 삭제.
/// 이 로그인은 템플릿을 올리고 관리하는 데만 쓴다. 루틴·식사·휴가 같은 개인 기록은 로그인과 무관하고, iCloud 계정과도 별개다.
struct CommunityAccountSection: View {
    @Environment(CommunityStore.self) private var community
    /// 계정 삭제 같은 관리 동작까지 보여 줄지. 게시 화면에서는 로그인만 보여 준다.
    var showsManagement = false

    @State private var nonce = ""
    @State private var error: String?
    @State private var isWorking = false
    @State private var confirmsDeletion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if community.isSignedIn {
                HStack(spacing: 8) {
                    Label("로그인됨", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.callout.weight(.medium))
                    Spacer(minLength: 8)
                    if showsManagement {
                        Button("로그아웃") { run { await community.signOut() } }
                        Button("계정 삭제", role: .destructive) { confirmsDeletion = true }
                    }
                }
                .controlSize(.small)
                if showsManagement {
                    Text("로그아웃해도 올려 둔 템플릿은 남고, 내 루틴·식사·휴가 기록은 그대로예요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("템플릿을 올리거나 신고·차단하려면 로그인이 필요해요. 둘러보기와 가져오기, 내 기록은 로그인 없이 그대로 쓸 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                signInControl
            }
            if isWorking { ProgressView().controlSize(.small) }
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .alert("계정을 삭제할까요?", isPresented: $confirmsDeletion) {
            Button("삭제", role: .destructive) { run { try await community.deleteAccount() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("서버의 계정과 내가 올린 템플릿이 지워져요. 이 기기의 루틴·식사·휴가 기록과, 다른 사람이 이미 가져간 루틴은 그대로예요.")
        }
    }

    @ViewBuilder
    private var signInControl: some View {
        if community.isMock {
            // 시험용 서버: 실제 로그인을 거치지 않는다.
            Button("시험용 계정으로 로그인") {
                run { try await community.signIn(appleIDToken: "demo", nonce: "") }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.small)
        } else if community.allowsAppleSignIn {
            SignInWithAppleButton(.signIn) { request in
                // 이름·이메일을 요청하지 않는다. 게시자 이름은 사용자가 따로 적는다.
                request.requestedScopes = []
                nonce = Self.randomNonce()
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                        error = "Apple 로그인 정보를 읽지 못했어요."
                        return
                    }
                    run { try await community.signIn(appleIDToken: token, nonce: nonce) }
                case .failure(let failure):
                    // 사용자가 창을 닫은 것은 오류로 보이지 않게 한다.
                    if (failure as? ASAuthorizationError)?.code != .canceled { error = "로그인하지 못했어요. 다시 시도해 주세요." }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: 260, minHeight: 36, maxHeight: 40)
        } else {
            Text("Apple 로그인 설정이 끝나면 여기서 로그인할 수 있어요.")
                .font(.caption.weight(.medium))
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        error = nil
        Task {
            do { try await work() } catch { self.error = CommunityStore.message(error) }
            isWorking = false
        }
    }

    /// 로그인 요청마다 새로 만드는 값. 원문은 서버로, 해시는 Apple로 간다(토큰 재사용을 막는다).
    static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in characters.randomElement(using: &generator) ?? "0" })
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
