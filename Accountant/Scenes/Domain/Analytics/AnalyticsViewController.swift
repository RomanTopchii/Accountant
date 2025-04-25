//
//  AnalyticsViewController.swift
//  Accounting
//
//  Created by Roman Topchii on 28.04.2020.
//  Copyright © 2020 Roman Topchii. All rights reserved.
//
//

import UIKit
import Charts

class AnalyticsViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var rootAccountButton: UIButton!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var scrollView: UIScrollView!
    var toolBar: UIToolbar = {
        var toolBar = UIToolbar()
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        return toolBar
    }()
    var picker: UIPickerView = {
        var picker = UIPickerView()
        picker.backgroundColor = .systemBackground
        picker.setValue(UIColor.label, forKey: "textColor")
        picker.contentMode = .center
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()

    var isUserHasPaidAccess = false

    private let coreDataStack = CoreDataStack.shared
    var context = CoreDataStack.shared.persistentContainer.viewContext

    unowned var analyticsTableViewController: AnalyticsTableViewController!

    private var slides: [UIView] = []

    private let calendar = Calendar.current
    private var dateOfLastChangesInDB: Date?
    private var rootAccount: Account?

    // transferedData
    var account: Account?
    var transferedDateInterval: DateInterval?
    var sortCategoryBy: SortCategoryType = .nineToZero
    var dateComponent: Calendar.Component = .day
    //

    var presentingCurrency: Currency!
    private var presentingData: PresentingData!

    private var dateInterval: DateInterval! {
        didSet {
            transferedDateInterval = dateInterval
            updateUI()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        picker.delegate = self
        picker.dataSource = self

        context = CoreDataStack.shared.persistentContainer.viewContext
        NotificationCenter.default.addObserver(self, selector: #selector(self.environmentDidChange),
                                               name: .environmentDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadProAccessData),
                                               name: .receivedProAccessData, object: nil)

        reloadProAccessData()

        presentingCurrency = CurrencyHelper.getAccountingCurrency(context: context)!
        scrollView.delegate = self

        rootAccount = AccountHelper.getAccountWithPath(LocalizationManager.getLocalizedName(.accounts),
                                                      context: context)

        rootAccountButton.isHidden = account != nil
        if account == nil {
            account = AccountHelper.getAccountWithPath(LocalizationManager.getLocalizedName(.expense),
                                                 context: context)
            rootAccountButton.setTitle(account?.name, for: .normal)

            if let row = rootAccount!.directChildrenList
                .sorted(by: {$0.name < $1.name})
                .map({$0.name})
                .firstIndex(of: account?.name ?? "") {
                picker.selectRow(row, inComponent: 0, animated: false)
            }
        }
        scrollView.addConstraint(NSLayoutConstraint(item: self.scrollView!,
                                                    attribute: NSLayoutConstraint.Attribute.height,
                                                    relatedBy: NSLayoutConstraint.Relation.equal,
                                                    toItem: self.scrollView!,
                                                    attribute: NSLayoutConstraint.Attribute.width,
                                                    multiplier: self.view.frame.size.width/414.0,
                                                    constant: 0))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.tabBarController?.navigationItem.rightBarButtonItem = nil
        self.tabBarController?.navigationItem.leftBarButtonItem = nil
        setTitle()
        if isNeedUpdateAll() {
            dateOfLastChangesInDB = UserProfileService.getDateOfLastChangesInDB()
            scrollView.scrollToLeft(animated: false)
            setDateIntervalInitialValue()
            updateUI()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .environmentDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .receivedProAccessData, object: nil)
    }

    @IBAction func onRootAccountButoonClick(_ sender: Any) {
        self.view.addSubview(picker)
        picker.widthAnchor.constraint(equalTo: self.view.widthAnchor).isActive = true
        picker.bottomAnchor.constraint(equalTo: self.view.bottomAnchor,
                                       constant: -(self.tabBarController?.tabBar.frame.height ?? 0)).isActive = true
        picker.heightAnchor.constraint(equalToConstant: 180).isActive = true

        self.view.addSubview(toolBar)
        toolBar.widthAnchor.constraint(equalTo: self.view.widthAnchor).isActive = true
        toolBar.bottomAnchor.constraint(equalTo: self.picker.topAnchor).isActive = true
        toolBar.heightAnchor.constraint(equalToConstant: 45).isActive = true
        toolBar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                         UIBarButtonItem.init(title: "Done", style: .done, target: self,
                                              action: #selector(onDoneButtonTapped))]
    }

    @objc public func onDoneButtonTapped() {
        toolBar.removeFromSuperview()
        picker.removeFromSuperview()
    }

    func setDateIntervalInitialValue() {
        if let transferedDateInterval = transferedDateInterval {
            dateInterval = transferedDateInterval
        }
        if dateInterval == nil {
            resetDateIntervalValue()
        }
    }

    private func resetDateIntervalValue() {
        if account?.type.balanceCalcFullTime == true {
            guard let leftBorderDate = TransactionHelper.getFirstTransactionDate(context: context),
                  let rightBorderDate = calendar.dateInterval(of: .day, for: Date())?.end else {return}
            dateInterval = DateInterval(start: leftBorderDate, end: rightBorderDate)
        } else {
            guard let leftBorderDate = calendar.dateInterval(of: .month, for: Date())?.start,
                  let rightBorderDate = calendar.dateInterval(of: .day, for: Date())?.end else {return}
            dateInterval = DateInterval(start: leftBorderDate, end: rightBorderDate)
        }
    }

    private func isNeedUpdateAll() -> Bool {
        if dateOfLastChangesInDB == nil || dateOfLastChangesInDB != UserProfileService.getDateOfLastChangesInDB() {
            return true
        }
        return false
    }

    /**
     This method fill all views
     - update tableView for current/seted timeInterval
     - create slides and set tis slides to scrollView
     - manage pageControl
     */
    func updateUI() {
        guard let account = account else {return}
        do {
            presentingData = try account.prepareDataToShow(dateInterval: dateInterval,
                                                           selectedCurrency: presentingCurrency,
                                                           dateComponent: dateComponent,
                                                           sortTableDataBy: sortCategoryBy)
        } catch let error {
            let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""),
                                          message: "\(error.localizedDescription)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            self.present(alert, animated: true, completion: nil)
        }

        presentingData.sortTableDataBy(sortCategoryBy)
        picker.reloadAllComponents()

        analyticsTableViewController.account = account
        analyticsTableViewController.dateInterval = dateInterval
        analyticsTableViewController.listOfAccountsToShow = presentingData.tableData
        analyticsTableViewController.sortCategoryBy = sortCategoryBy
        analyticsTableViewController.dateComponent = dateComponent
        analyticsTableViewController.tableView.reloadData()

        slides = createSlides()
        setupSlideScrollView(slides: slides)

        pageControl.numberOfPages = slides.count
        pageControl.hidesForSinglePage = true
        pageControl.isUserInteractionEnabled = false
    }

    func sortTableView() {
        presentingData.sortTableDataBy(sortCategoryBy)
        analyticsTableViewController.listOfAccountsToShow = presentingData.tableData
        analyticsTableViewController.tableView.reloadData()
    }

    // swiftlint:disable line_length
    private func createSlides() -> [UIView] {
       let slide1 = ChartsManager.setPieChartView(dataForPieCharts: presentingData.getDataForPieChart(distributionType: .amount,
                                                                                                      showDate: true))
        let slide2 = ChartsManager.setLineChartView(chartData: presentingData.lineChartData)
        let slide3 = ChartsManager.setPieChartView(dataForPieCharts: presentingData.getDataForPieChart(distributionType: .currecy,
                                                                                                       showDate: false))
        let slide4 = ChartsManager.setPieChartView(dataForPieCharts: presentingData.getDataForPieChart(distributionType: .holder,
                                                                                                       showDate: false))
        let slide5 = ChartsManager.setPieChartView(dataForPieCharts: presentingData.getDataForPieChart(distributionType: .keeper,
                                                                                                       showDate: false))
        slide1.tag = 1
        slide2.tag = 2
        slide3.tag = 3
        slide4.tag = 4
        slide5.tag = 5
        return [slide1, slide2, slide3, slide4, slide5]
    }
    // swiftlint:enable line_length

    private func setupSlideScrollView(slides: [UIView]) {
        for index in 1...6 {
            if let viewWithTag = scrollView.viewWithTag(index) {
                viewWithTag.removeFromSuperview()
            }
        }
        scrollView.contentSize = CGSize(width: scrollView.frame.width * CGFloat(slides.count),
                                        height: scrollView.frame.height)
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        for index in 0 ..< slides.count {
            slides[index].frame = CGRect(x: view.frame.width * CGFloat(index),
                                         y: 44,
                                         width: view.frame.width,
                                         height: view.frame.width / 414.0 * view.frame.width-44)
            scrollView.addSubview(slides[index])
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = round(scrollView.contentOffset.x/view.frame.width)
        pageControl.currentPage = Int(pageIndex)

        let maximumHorizontalOffset: CGFloat = scrollView.contentSize.width - scrollView.frame.width
        let currentHorizontalOffset: CGFloat = scrollView.contentOffset.x

        let maximumVerticalOffset: CGFloat = scrollView.contentSize.height - scrollView.frame.height
        let currentVerticalOffset: CGFloat = scrollView.contentOffset.y

        let percentageHorizontalOffset: CGFloat = currentHorizontalOffset / maximumHorizontalOffset
        let percentageVerticalOffset: CGFloat = currentVerticalOffset / maximumVerticalOffset

        let percentOffset: CGPoint = CGPoint(x: percentageHorizontalOffset, y: percentageVerticalOffset)

        if slides.count == 4 {
            if percentOffset.x > 0 && percentOffset.x <= 0.33 {
                slides[0].transform = CGAffineTransform(scaleX: (0.33-percentOffset.x)/0.33,
                                                        y: (0.33-percentOffset.x)/0.33)
                slides[1].transform = CGAffineTransform(scaleX: percentOffset.x/0.33,
                                                        y: percentOffset.x/0.33)
            } else if percentOffset.x > 0.33 && percentOffset.x <= 0.66 {
                slides[1].transform = CGAffineTransform(scaleX: (0.66-percentOffset.x)/0.33,
                                                        y: (0.66-percentOffset.x)/0.33)
                slides[2].transform = CGAffineTransform(scaleX: percentOffset.x/0.66,
                                                        y: percentOffset.x/0.66)
            } else if percentOffset.x > 0.66 && percentOffset.x <= 1 {
                slides[2].transform = CGAffineTransform(scaleX: (1-percentOffset.x)/0.33,
                                                        y: (1-percentOffset.x)/0.33)
                slides[3].transform = CGAffineTransform(scaleX: percentOffset.x,
                                                        y: percentOffset.x)
            }
        } else if slides.count == 3 {
            if percentOffset.x > 0 && percentOffset.x <= 0.5 {
                slides[0].transform = CGAffineTransform(scaleX: (0.5-percentOffset.x)/0.5,
                                                        y: (0.5-percentOffset.x)/0.5)
                slides[1].transform = CGAffineTransform(scaleX: percentOffset.x/0.5,
                                                        y: percentOffset.x/0.5)
            } else if percentOffset.x > 0.5 && percentOffset.x <= 1 {
                slides[1].transform = CGAffineTransform(scaleX: (1-percentOffset.x)/0.5,
                                                        y: (1-percentOffset.x)/0.5)
                slides[2].transform = CGAffineTransform(scaleX: percentOffset.x,
                                                        y: percentOffset.x)
            }
        }
    }

    private func setTitle() {
        if let account = account {
            if account.parent?.parent != nil {
                self.navigationItem.title = account.name
            } else {
                self.tabBarController?.navigationItem.title = NSLocalizedString("Analytics", comment: "")
            }
        } else {
            self.tabBarController?.navigationItem.title = NSLocalizedString("Analytics", comment: "")
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Constants.Segue.goToConfigurationVC {
            guard let configAnalyticVC = segue.destination as? ConfigureAnalyticsViewController else {return}
            configAnalyticVC.analyticsViewController = self
            configAnalyticVC.transferedDateInterval = dateInterval
            configAnalyticVC.dateComponent = dateComponent
            configAnalyticVC.sortCategoryBy = sortCategoryBy
        } else if segue.identifier == Constants.Segue.goToAnalyticsTVC {
            analyticsTableViewController = segue.destination as? AnalyticsTableViewController
            analyticsTableViewController.dateInterval = dateInterval
        }
    }

    @objc func environmentDidChange() {
        context = CoreDataStack.shared.persistentContainer.viewContext
        presentingCurrency = CurrencyHelper.getAccountingCurrency(context: context)!
        rootAccount = AccountHelper.getAccountWithPath(LocalizationManager.getLocalizedName(.accounts),
                                                       context: context)
        account = AccountHelper.getAccountWithPath(LocalizationManager.getLocalizedName(.expense),
                                                   context: context)
        rootAccountButton.setTitle(account?.name, for: .normal)
        
        analyticsTableViewController.presentingCurrency = presentingCurrency
        analyticsTableViewController.account = account
        
        if let row = rootAccount!.directChildrenList
            .sorted(by: {$0.name < $1.name})
            .map({$0.name})
            .firstIndex(of: account?.name ?? "") {
            picker.selectRow(row, inComponent: 0, animated: false)
        }

        resetDateIntervalValue()
    }

    @objc func reloadProAccessData() {
        AccessManager.hasProAccess { hasAccess in self.isUserHasPaidAccess = hasAccess }
    }
}

extension AnalyticsViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return rootAccount?.directChildrenList.count ?? 0
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return rootAccount!.directChildrenList.sorted(by: {$0.name < $1.name})[row].name
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectAccount = rootAccount!.directChildrenList.sorted(by: {$0.name < $1.name})[row]
        account = AccountHelper.getAccountWithPath(selectAccount.path, context: context)
        rootAccountButton.setTitle(account?.name ?? "", for: .normal)
        resetDateIntervalValue()
    }
}
