import Foundation
import AppAuth

class AuthenticationViewModel: ObservableObject {
    @Published var authState: OIDAuthState?
    @Published var isAuthenticated = false
    @Published var error: String?

    private var userAgentSession: OIDExternalUserAgentSession?
    typealias PostRegistrationCallback = (_ configuration: OIDServiceConfiguration?, _ registrationResponse: OIDRegistrationResponse?) -> Void


    private func getHostingViewController() -> UIViewController {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            return scene!.keyWindow!.rootViewController!
        }
    
    func doClientRegistration(configuration: OIDServiceConfiguration, redirectURL:URL,  callback: @escaping PostRegistrationCallback) {

            let request: OIDRegistrationRequest = OIDRegistrationRequest(configuration: configuration,
                                                                         redirectURIs: [redirectURL],
                                                                         responseTypes: nil,
                                                                         grantTypes: nil,
                                                                         subjectType: nil,
                                                                         tokenEndpointAuthMethod: "client_secret_post",
                                                                         additionalParameters: nil)

            // performs registration request
            OIDAuthorizationService.perform(request) { response, error in

                if let regResponse = response {
                    self.authState = OIDAuthState(registrationResponse: regResponse)
                    callback(configuration, regResponse)
                } else {
                    self.error = "Registration Error: \(error?.localizedDescription ?? "DEFAULT_ERROR")"
                    self.authState = nil
                }
            }
        }
    
    func doAuthWithAutoCodeExchange(configuration: OIDServiceConfiguration, redirectURL: URL, clientID: String, clientSecret: String?) {

            // builds authentication request
            let request = OIDAuthorizationRequest(configuration: configuration,
                                                  clientId: clientID,
                                                  clientSecret: clientSecret,
                                                  scopes: [OIDScopeOpenID, OIDScopeProfile],
                                                  redirectURL: redirectURL,
                                                  responseType: OIDResponseTypeCode,
                                                  additionalParameters: nil)

            // performs authentication request
            print("Initiating authorization request with scope: \(request.scope ?? "DEFAULT_SCOPE")")

        self.userAgentSession = OIDAuthState.authState(byPresenting: request, presenting: self.getHostingViewController()) { authState, error in

                if let authState = authState {
                    self.authState = authState
                    print("Got authorization access tokens. Access token: \(authState.lastTokenResponse?.accessToken ?? "DEFAULT_TOKEN")")
                    print("Got authorization ID tokens. ID token: \(authState.lastTokenResponse?.idToken ?? "DEFAULT_TOKEN")")
                    self.isAuthenticated = true;
                } else {
                    self.error = "Authorization error: \(error?.localizedDescription ?? "DEFAULT_ERROR")"
                    self.authState = nil
                }
            }
        }
    
    func authenticate() {
        guard let issuerURL = URL(string: "https://idp.au.test.truuth.id/acme") else {
            self.error = "Validation Error: Invalid Issuer"
                            return
                        }
        guard let redirectURL = URL(string: "id.truuth.client:/callback") else {
            self.error = "Validation Error: Invalid RedirectURI"
            return
        }
        
        let clientID: String = "0JT77eDIAgsdBdnJmBa9";
        

      
        // discovers endpoints
                OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { configuration, error in

                    guard let config = configuration else {
                        self.error = "Error : retrieving discovery document: \(error?.localizedDescription ?? "DEFAULT_ERROR")"
                        self.authState = nil
                        return
                    }
                    if let clientId = clientID as! String? {
                        self.doAuthWithAutoCodeExchange(configuration: config, redirectURL: redirectURL, clientID: clientId, clientSecret: nil)
                    } else {
                        self.doClientRegistration(configuration: config, redirectURL: redirectURL) { configuration, response in

                            guard let configuration = configuration, let clientID = response?.clientID else {
                                self.error = "Error : retrieving configuration OR clientID"
                                return
                            }

                            self.doAuthWithAutoCodeExchange(configuration: configuration,
                                                            redirectURL: redirectURL,
                                                            clientID: clientID,
                                                            clientSecret: response?.clientSecret)
               }
                    }}}
       }
