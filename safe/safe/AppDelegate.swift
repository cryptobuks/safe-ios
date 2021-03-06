//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Crashlytics
import Fabric
import UIKit
import SafeAppUI
import IdentityAccessApplication
import IdentityAccessDomainModel
import IdentityAccessImplementations
import MultisigWalletApplication
import MultisigWalletDomainModel
import MultisigWalletImplementations
import Database
import Common
import CommonImplementations
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, Resettable {

    var window: UIWindow?
    lazy var coordinator = AppFlowCoordinator()
    var identityAccessDB: Database?
    var multisigWalletDB: Database?
    var secureStore: SecureStore?
    var appConfig: AppConfig!
    let filesystemGuard = FileSystemGuard()

    let defaultBundleIdentifier = "io.gnosis.safe" // DO NOT CHANGE BECAUSE DEFAULT DATABASE LOCATION MIGHT CHANGE

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics.self])

        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
        Messaging.messaging().shouldEstablishDirectChannel = true

        // https://firebase.google.com/docs/cloud-messaging/ios/client
        // for devices running iOS 10 and above, you must assign your delegate object to the UNUserNotificationCenter
        // object to receive display notifications, and the FIRMessaging object to receive data messages,
        // before your app finishes launching.
        UNUserNotificationCenter.current().delegate = self

        appConfig = try! AppConfig.loadFromBundle()!
        configureDependencyInjection()

        #if DEBUG
        TestSupport.shared.addResettable(self)
        TestSupport.shared.setUp()
        #endif

        createWindow()
        UIApplication.shared.applicationIconBadgeNumber = 0
        synchronise()
        return true
    }

    func configureDependencyInjection() {
        configureIdentityAccess()
        configureMultisigWallet()
        configureEthereum()
    }

    private func configureIdentityAccess() {
        IdentityAccessApplication.ApplicationServiceRegistry.put(service: AuthenticationApplicationService(),
                                                                 for: AuthenticationApplicationService.self)
        IdentityAccessApplication.ApplicationServiceRegistry.put(service: SystemClockService(), for: Clock.self)
        IdentityAccessApplication.ApplicationServiceRegistry.put(service: LogService.shared, for: Logger.self)
        IdentityAccessDomainModel.DomainRegistry.put(service: BiometricService(),
                                                     for: BiometricAuthenticationService.self)
        IdentityAccessDomainModel.DomainRegistry.put(service: SystemClockService(), for: Clock.self)
        let encryptionService = IdentityAccessImplementations.CommonCryptoEncryptionService()
        IdentityAccessDomainModel.DomainRegistry.put(service: encryptionService,
                                                     for: IdentityAccessDomainModel.EncryptionService.self)
        IdentityAccessDomainModel.DomainRegistry.put(service: IdentityService(), for: IdentityService.self)
        setUpIdentityAccessDatabase()
    }

    private func configureMultisigWallet() {
        let walletService = WalletApplicationService(configuration: appConfig.walletApplicationServiceConfiguration)
        MultisigWalletApplication.ApplicationServiceRegistry.put(service: walletService,
                                                                 for: WalletApplicationService.self)
        MultisigWalletApplication.ApplicationServiceRegistry.put(service: RecoveryApplicationService(),
                                                                 for: RecoveryApplicationService.self)
        MultisigWalletApplication.ApplicationServiceRegistry.put(service: WalletSettingsApplicationService(),
                                                                 for: WalletSettingsApplicationService.self)

        MultisigWalletApplication.ApplicationServiceRegistry.put(service: LogService.shared, for: Logger.self)
        let notificationService = HTTPNotificationService(url: appConfig.notificationServiceURL,
                                                          logger: LogService.shared)
        MultisigWalletDomainModel.DomainRegistry.put(service: notificationService, for: NotificationDomainService.self)
        MultisigWalletDomainModel.DomainRegistry.put(
            service: HTTPTokenListService(url: appConfig.tokenListServiceURL, logger: LogService.shared),
            for: TokenListDomainService.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: PushTokensService(), for: PushTokensDomainService.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: AccountUpdateDomainService(),
                                                     for: AccountUpdateDomainService.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: SynchronisationService(retryInterval: 0.5),
                                                     for: SynchronisationDomainService.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: EventPublisher(), for: EventPublisher.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: System(), for: System.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: ErrorStream(), for: ErrorStream.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: DeploymentDomainService(),
                                                     for: DeploymentDomainService.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: TransactionDomainService(),
                                                     for: TransactionDomainService.self)
        let config = RecoveryDomainServiceConfig(masterCopyAddresses: appConfig.masterCopyAddresses,
                                                 multiSendAddress: appConfig.multiSendAddress)
        MultisigWalletDomainModel.DomainRegistry.put(service: RecoveryDomainService(config: config),
                                                     for: RecoveryDomainService.self)
        MultisigWalletDomainModel.DomainRegistry.put(service: WalletSettingsDomainService(config: config),
                                                     for: WalletSettingsDomainService.self)

        let relay = EventRelay(publisher: MultisigWalletDomainModel.DomainRegistry.eventPublisher)
        MultisigWalletApplication.ApplicationServiceRegistry.put(service: relay, for: EventRelay.self)

        setUpMultisigDatabase()
    }

    private func configureEthereum() {
        MultisigWalletApplication.ApplicationServiceRegistry.put(service: EthereumApplicationService(),
                                                                 for: EthereumApplicationService.self)
        MultisigWalletApplication.ApplicationServiceRegistry.put(service: LogService.shared, for: Logger.self)

        let chainId = EIP155ChainId(rawValue: appConfig.encryptionServiceChainId)!
        let encryptionService = MultisigWalletImplementations.EncryptionService(chainId: chainId)
        MultisigWalletDomainModel.DomainRegistry.put(service: encryptionService,
                                                     for: MultisigWalletDomainModel.EncryptionDomainService.self)
        let relayService = GnosisTransactionRelayService(url: appConfig.relayServiceURL, logger: LogService.shared)
        MultisigWalletDomainModel.DomainRegistry.put(service: relayService, for: TransactionRelayDomainService.self)

        secureStore = KeychainService(identifier: defaultBundleIdentifier)
        MultisigWalletDomainModel.DomainRegistry.put(service:
            SecureExternallyOwnedAccountRepository(store: secureStore!),
                                                     for: ExternallyOwnedAccountRepository.self)

        let nodeService = InfuraEthereumNodeService(url: appConfig.nodeServiceConfig.url,
                                                    chainId: appConfig.nodeServiceConfig.chainId)
        MultisigWalletDomainModel.DomainRegistry.put(service: nodeService, for: EthereumNodeDomainService.self)
    }

    private func setUpIdentityAccessDatabase() {
        do {
            let db = SQLiteDatabase(name: "IdentityAccess",
                                    fileManager: FileManager.default,
                                    sqlite: DataProtectionAwareCSQLite3(filesystemGuard: filesystemGuard),
                                    bundleId: Bundle.main.bundleIdentifier ?? defaultBundleIdentifier)
            identityAccessDB = db
            let userRepo = DBSingleUserRepository(db: db)
            let gatekeeperRepo = DBSingleGatekeeperRepository(db: db)
            IdentityAccessDomainModel.DomainRegistry.put(service: userRepo, for: SingleUserRepository.self)
            IdentityAccessDomainModel.DomainRegistry.put(service: gatekeeperRepo, for: SingleGatekeeperRepository.self)

            if !db.exists {
                try db.create()
                try userRepo.setUp()
                gatekeeperRepo.setUp()

                try ApplicationServiceRegistry.authenticationService
                    .createAuthenticationPolicy(sessionDuration: 60,
                                                maxPasswordAttempts: 3,
                                                blockedPeriodDuration: 15)
            }

            let migrationRepo = DBMigrationRepository(db: db)
            migrationRepo.setUp()
            let migrationService = DBMigrationService(repository: migrationRepo)
            registerIdentityAccessDatabaseMigrations(service: migrationService)
            migrationService.migrate()
        } catch let e {
            ErrorHandler.showFatalError(log: "Failed to set up identity access database", error: e)
        }
    }

    private func registerIdentityAccessDatabaseMigrations(service: DBMigrationService) {
        // identity access db migrations go here
    }

    private func setUpMultisigDatabase() {
        do {
            let db = SQLiteDatabase(name: "MultisigWallet",
                                    fileManager: FileManager.default,
                                    sqlite: DataProtectionAwareCSQLite3(filesystemGuard: filesystemGuard),
                                    bundleId: Bundle.main.bundleIdentifier ?? defaultBundleIdentifier)
            multisigWalletDB = db
            let walletRepo = DBWalletRepository(db: db)
            let portfolioRepo = DBSinglePortfolioRepository(db: db)
            let accountRepo = DBAccountRepository(db: db)
            let transactionRepo = DBTransactionRepository(db: db)
            let tokenListItemRepo = DBTokenListItemRepository(db: db)
            MultisigWalletDomainModel.DomainRegistry.put(service: walletRepo, for: WalletRepository.self)
            MultisigWalletDomainModel.DomainRegistry.put(service: portfolioRepo, for: SinglePortfolioRepository.self)
            MultisigWalletDomainModel.DomainRegistry.put(service: accountRepo, for: AccountRepository.self)
            MultisigWalletDomainModel.DomainRegistry.put(service: transactionRepo, for: TransactionRepository.self)
            MultisigWalletDomainModel.DomainRegistry.put(service: tokenListItemRepo, for: TokenListItemRepository.self)

            if !db.exists {
                try db.create()
            }
            portfolioRepo.setUp()
            walletRepo.setUp()
            accountRepo.setUp()
            transactionRepo.setUp()
            tokenListItemRepo.setUp()

            let migrationRepo = DBMigrationRepository(db: db)
            migrationRepo.setUp()
            let migrationService = DBMigrationService(repository: migrationRepo)
            registerMultisigDatabaseMigrations(service: migrationService)
            migrationService.migrate()
        } catch let e {
            ErrorHandler.showFatalError(log: "Failed to set up multisig database", error: e)
        }
    }

    private func registerMultisigDatabaseMigrations(service: DBMigrationService) {
        // multisig wallet db migrations go here
    }

    private func createWindow() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        coordinator.setUp()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        coordinator.appEntersForeground()
        UIApplication.shared.applicationIconBadgeNumber = 0
        synchronise()
    }

    private func synchronise() {
        DispatchQueue.global().async {
            MultisigWalletDomainModel.DomainRegistry.syncService.sync()
        }
        DispatchQueue.global().async {
            MultisigWalletDomainModel.DomainRegistry.syncService.syncTransactions()
        }
    }

    func resetAll() {
        if let db = identityAccessDB {
            try? db.destroy()
            setUpIdentityAccessDatabase()
        }
        if let db = multisigWalletDB {
            try? db.destroy()
            setUpMultisigDatabase()
        }
        if let store = secureStore {
            try? store.destroy()
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LogService.shared.error("Failed to registed to remote notifications", error: error)
    }

}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        LogService.shared.debug("willPresent notification with userInfo: \(userInfo)")
        UIApplication.shared.applicationIconBadgeNumber = 0
        coordinator.receive(message: userInfo)
        completionHandler([])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        LogService.shared.debug("didReceive notification with userInfo: \(userInfo)")
        coordinator.receive(message: userInfo)
        completionHandler()
    }

}

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        LogService.shared.debug("Firebase registration token: \(fcmToken)")
    }

    // This is called if APNS messaging is disabled and the app is in foreground
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        LogService.shared.debug("Received data message: \(remoteMessage.appData)")
        coordinator.receive(message: remoteMessage.appData)
    }

}
