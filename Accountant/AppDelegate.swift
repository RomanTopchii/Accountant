//
//  AppDelegate.swift
//  Accountant
//
//  Created by Roman Topchii on 01.06.2021.
//

import UIKit
import Purchases
//import GoogleMobileAds

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        //MARK: REVENUECAT initializing
        Purchases.debugLogsEnabled = true
        Purchases.configure(withAPIKey: Constants.APIKey.revenueCat)
        
        //MARK:GOOGLE ADD initializing
        //        GADMobileAds.sharedInstance().start(completionHandler: nil)
        
        //MARK: Loading exchange rates
        if UserProfile.isAppLaunchedBefore() {
            ExchangeRatesLoadingService.loadExchangeRates(context: CoreDataStack.shared.persistentContainer.newBackgroundContext())
        }
        NetworkServices.loadCurrency(date: Date()) { (currencyHistoricalData, error) in
            if let currencyHistoricalData = currencyHistoricalData {
                DispatchQueue.main.async {
                    UserProfile.setExchangeRate(currencyHistoricalData)
                    print("Done. Exchange rate loaded")
                }
            }
        }
        
        
        //MARK: Check is app launched before
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        if !UserProfile.isAppLaunchedBefore() {
            let vc = storyBoard.instantiateViewController(withIdentifier: Constants.Storyboard.welcomeViewController) as! WelcomeViewController
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.makeKeyAndVisible()
            window?.rootViewController = UINavigationController(rootViewController: vc)
        }
        else if UserProfile.getUserAuth() == .bioAuth {
            let authVC = storyBoard.instantiateViewController(withIdentifier: Constants.Storyboard.bioAuthViewController) as! BiometricAuthViewController
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.makeKeyAndVisible()
            window?.rootViewController = authVC
        }
        return true
    }
    
    func applicationDidEnterBackground(_ application : UIApplication) {
        if UserProfile.getUserAuth() != .none {
            UserProfile.setAppBecomeBackgroundDate(Date())
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        let calendar = Calendar.current
        print("UserProfile.setLastAccessCheckDate()", UserProfile.setLastAccessCheckDate())
        //MARK: - GET PURCHASER INFO
        if let lastAccessCheckDate = UserProfile.getLastAccessCheckDate(),
           let secureDate = calendar.date(byAdding: .hour, value: 6, to: lastAccessCheckDate),
           secureDate > Date() {
            Purchases.shared.purchaserInfo { (purchaserInfo, error) in
                if purchaserInfo?.entitlements.all["pro"]?.isActive == false,
                   let expirationDate = purchaserInfo?.expirationDate(forEntitlement: "pro"),
                   let secureDate = calendar.date(byAdding: .day, value: 3, to: expirationDate),
                   secureDate < Date() {
                    UserProfile.setUserAuth(.none)
                }
                NotificationCenter.default.post(name: .receivedProAccessData, object: nil)
                UserProfile.setLastAccessCheckDate()
            }
        }
        
        //MARK: - AUTH BLOCK
        let userAuthType = UserProfile.getUserAuth()
        if userAuthType == .bioAuth {
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let authVC = storyBoard.instantiateViewController(withIdentifier: Constants.Storyboard.bioAuthViewController) as! BiometricAuthViewController
            authVC.previousNavigationStack = window?.rootViewController
            window = UIWindow(frame: UIScreen.main.bounds)
            
            if let appBecomeBackgroundDate = UserProfile.getAppBecomeBackgroundDate() {
                if let secureDate = calendar.date(byAdding: .second, value: 120, to: appBecomeBackgroundDate), secureDate < Date() {
                    window?.makeKeyAndVisible()
                    window?.rootViewController = authVC
                }
                else {
                    let tabBar = storyBoard.instantiateViewController(withIdentifier: Constants.Storyboard.tabBarController)
                    window?.makeKeyAndVisible()
                    window?.rootViewController = UINavigationController(rootViewController: tabBar)
                }
            }
            else {
                window?.makeKeyAndVisible()
                window?.rootViewController = authVC
            }
        }
        else if userAuthType == .appAuth {
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let authVC = storyBoard.instantiateViewController(withIdentifier: Constants.Storyboard.authPinAndBioViewController) as! AuthPinAndBiometricViewController
            authVC.previousNavigationStack = window?.rootViewController
            window = UIWindow(frame: UIScreen.main.bounds)
            if let appBecomeBackgroundDate = UserProfile.getAppBecomeBackgroundDate() {
                if let secureDate = calendar.date(byAdding: .second, value: 120, to: appBecomeBackgroundDate), secureDate < Date() {
                    window?.makeKeyAndVisible()
                    window?.rootViewController = authVC
                }
                else {
                    let tabBar = storyBoard.instantiateViewController(withIdentifier: Constants.Storyboard.tabBarController)
                    window?.makeKeyAndVisible()
                    window?.rootViewController = UINavigationController(rootViewController: tabBar)
                }
            }
            else {
                window?.makeKeyAndVisible()
                window?.rootViewController = authVC
            }
        }
    }
}
