//
//  AccountNavigationTableViewCell.swift
//  Accountant
//
//  Created by Roman Topchii on 21.09.2021.
//

import UIKit

class AccountNavigationCell: UITableViewCell {

    private let mainView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let nameStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor =  Colors.Main.defaultCellTextColor
        label.lineBreakMode = .byCharWrapping
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let pathLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemGray
        label.font = UIFont.systemFont(ofSize: 14)
        label.lineBreakMode = .byCharWrapping
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let amountLabel: UILabel = {
        let label = UILabel()
        label.textColor = Colors.Main.defaultCellTextColor
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    func configureCellFor(_ account: Account, showPath: Bool = false,
                                 showHiddenAccounts: Bool) {
        contentView.addSubview(mainView)
        mainView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8).isActive = true
        mainView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8).isActive = true
        mainView.safeAreaLayoutGuide.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2).isActive = true
        mainView.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: contentView.bottomAnchor,
                                                             constant: -2).isActive = true
        mainView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true

        mainView.addSubview(nameStackView)
        nameStackView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor).isActive = true
        nameStackView.topAnchor.constraint(equalTo: mainView.topAnchor).isActive = true
        nameStackView.bottomAnchor.constraint(equalTo: mainView.bottomAnchor).isActive = true

        nameStackView.addArrangedSubview(nameLabel)
        nameStackView.addArrangedSubview(pathLabel)
        pathLabel.widthAnchor.constraint(lessThanOrEqualTo: nameLabel.widthAnchor).isActive = true

        mainView.addSubview(amountLabel)
        amountLabel.trailingAnchor.constraint(equalTo: mainView.trailingAnchor).isActive = true
        amountLabel.centerYAnchor.constraint(equalTo: mainView.centerYAnchor).isActive = true
        amountLabel.bottomAnchor.constraint(equalTo: mainView.bottomAnchor).isActive = true
        amountLabel.leadingAnchor.constraint(equalTo: nameStackView.trailingAnchor, constant: 8).isActive = true

        nameStackView.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: .horizontal)
        pathLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: .horizontal)
        amountLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        if !account.childrenList.filter({$0.active || $0.active != showHiddenAccounts}).isEmpty {
            accessoryType = .disclosureIndicator
        } else {
            accessoryType = .none
        }
        pathLabel.isHidden = true
        nameLabel.text = account.name
        if showPath {
            pathLabel.text = account.path
            pathLabel.isHidden = false
        }
        if account.active {
            nameLabel.textColor = Colors.Main.defaultCellTextColor
            amountLabel.textColor = Colors.Main.defaultCellTextColor
        } else {
            nameLabel.textColor = .systemGray
            amountLabel.textColor = .systemGray
        }

        amountLabel.text = ""
    }
}
