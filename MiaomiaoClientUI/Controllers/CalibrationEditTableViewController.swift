//
//  GlucoseNotificationsSettingsTableViewController.swift
//  MiaomiaoClientUI
//
//  Created by Bjørn Inge Berg on 07/05/2019.
//  Copyright © 2019 Bjørn Inge Berg. All rights reserved.
//
import LoopKit
import LoopKitUI
import UIKit

import HealthKit
import MiaomiaoClient

public class CalibrationEditTableViewController: UITableViewController, mmTextFieldViewCellCellDelegate2 {
    public var cgmManager: MiaoMiaoClientManager?

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("CalibrationEditTableViewController will now disappear")
        disappearDelegate?.onDisappear()
    }

    public weak var disappearDelegate: SubViewControllerWillDisappear?

    private var newParams: DerivedAlgorithmParameters?

    public init(cgmManager: MiaoMiaoClientManager?) {
        self.cgmManager = cgmManager
        super.init(style: .grouped)

        newParams = cgmManager?.keychain.getLibreCalibrationData()

        // for testing only

         /*newParams = DerivedAlgorithmParameters(slope_slope: 0.0, slope_offset:0.0, offset_slope: 0.0, offset_offset: 0.0, isValidForFooterWithReverseCRCs: 1234, extraSlope: 1.0, extraOffset: 0.0)*/
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override public func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(AlarmTimeInputRangeCell.nib(), forCellReuseIdentifier: AlarmTimeInputRangeCell.className)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")

        tableView.register(GlucoseAlarmInputCell.nib(), forCellReuseIdentifier: GlucoseAlarmInputCell.className)

        tableView.register(TextFieldTableViewCell.nib(), forCellReuseIdentifier: TextFieldTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        tableView.register(SegmentViewCell.nib(), forCellReuseIdentifier: SegmentViewCell.className)

        tableView.register(MMSwitchTableViewCell.nib(), forCellReuseIdentifier: MMSwitchTableViewCell.className)

        tableView.register(MMTextFieldViewCell2.nib(), forCellReuseIdentifier: MMTextFieldViewCell2.className)
        self.tableView.rowHeight = 44
    }

    private enum CalibrationDataInfoRow: Int {
        case slopeslope
        case slopeoffset
        case offsetslope
        case offsetoffset
        case extraoffset
        case extraslope
        case isValidForFooterWithCRCs

        static let count = 7
    }

    private enum Section: Int {
        case CalibrationDataInfoRow
        case sync
    }

    override public func numberOfSections(in tableView: UITableView) -> Int {
        //dynamic number of schedules + sync row
        2
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .CalibrationDataInfoRow:
            return CalibrationDataInfoRow.count
        case .sync:
            return 1
        }
    }
    /*
    weak var slopeslopece: mmTextFieldViewCell2?
    weak var slopeslopeCell: mmTextFieldViewCell2?
    weak var slopeoffsetCell: mmTextFieldViewCell2?
    weak var offsetslopeCell: mmTextFieldViewCell2?
    weak var offsetoffsetCell: mmTextFieldViewCell2?
    weak var isValidForFooterWithCRCsCell: mmTextFieldViewCell2?
    */

    func mmTextFieldViewCellDidUpdateValue(_ cell: MMTextFieldViewCell2, value: String?) {
        if let value = value, let numVal = Double(value) {
            switch CalibrationDataInfoRow(rawValue: cell.tag)! {
            case .isValidForFooterWithCRCs:
                //this should not happen as crc can not change

                print("isValidForFooterWithCRCs was updated: \(numVal)")
            case .slopeslope:
                newParams?.slope_slope = numVal
                print("slopeslope was updated: \(numVal)")
            case .slopeoffset:
                newParams?.slope_offset = numVal
                print("slopeoffset was updated: \(numVal)")
            case .offsetslope:
                newParams?.offset_slope = numVal
                print("offsetslope was updated: \(numVal)")
            case .offsetoffset:
                newParams?.offset_offset = numVal
                print("offsetoffset was updated: \(numVal)")
            case .extraoffset:
                newParams?.extraOffset = numVal
                print("extraoffset was updated: \(numVal)")
            case .extraslope:
                newParams?.extraSlope = numVal
                print("extraslope was updated: \(numVal)")
            }
        }
    }

    // swiftlint:disable:next function_body_length
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Section.sync.rawValue {
            let cell = tableView.dequeueIdentifiableCell(cell: TextButtonTableViewCell.self, for: indexPath)

            cell.textLabel?.text = LocalizedString("Save calibrations", comment: "The title for Save calibration")
            return cell
        }
        let cell = tableView.dequeueIdentifiableCell(cell: MMTextFieldViewCell2.self, for: indexPath)
        cell.tag = indexPath.row
        cell.delegate = self

        switch CalibrationDataInfoRow(rawValue: indexPath.row)! {
        case .offsetoffset:

            cell.textInput?.text = String(newParams?.offset_offset ?? 0)
            cell.titleLabel.text = NSLocalizedString("offsetoffset", comment: "The title text for offsetoffset calibration setting")

        case .offsetslope:
            cell.textInput?.text = String(newParams?.offset_slope ?? 0)
            cell.titleLabel.text = NSLocalizedString("offsetslope", comment: "The title text for offsetslope calibration setting")

        case .slopeoffset:
            cell.textInput?.text = String(newParams?.slope_offset ?? 0)
            cell.titleLabel.text = NSLocalizedString("slopeoffset", comment: "The title text for slopeoffset calibration setting")
        case .slopeslope:
            cell.textInput?.text = String(newParams?.slope_slope ?? 0)
            cell.titleLabel.text = NSLocalizedString("slopeslope", comment: "The title text for slopeslope calibration setting")

        case .isValidForFooterWithCRCs:
            cell.textInput?.text = String(newParams?.isValidForFooterWithReverseCRCs ?? 0)

            cell.titleLabel.text = NSLocalizedString("IsValidForFooter", comment: "The title for the footer crc checksum linking these calibration values to this particular sensor")

            cell.isEnabled = false
        case .extraoffset:
            cell.textInput?.text = String(newParams?.extraOffset ?? 0)
            cell.titleLabel.text = NSLocalizedString("extraOffset", comment: "The title text for extra offset calibration setting")

        case .extraslope:
            cell.textInput?.text = String(newParams?.extraSlope ?? 0)
            cell.titleLabel.text = NSLocalizedString("extraSlope", comment: "The title text for extra slope calibration setting")
        }

        return cell
    }

    override public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == Section.sync.rawValue {
            return nil
        }
        return LocalizedString("Calibrations edit mode", comment: "The title text for the Calibrations edit mode")
    }

    override public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
         nil
    }

    override public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        true
    }

    // swiftlint:disable:next cyclomatic_complexity
    override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch  Section(rawValue: indexPath.section)! {
        case .CalibrationDataInfoRow:
            switch CalibrationDataInfoRow(rawValue: indexPath.row)! {
            case .slopeslope:
                print("slopeslope clicked")
            case .slopeoffset:
                print("slopeoffset clicked")

            case .offsetslope:
                print("offsetslope clicked")
            case .offsetoffset:
                print("offsetoffset clicked")
            case .isValidForFooterWithCRCs:
                print("isValidForFooterWithCRCs clicked")
            case .extraoffset:
                print("extraoffset clicked")
            case .extraslope:
                print("extraslope clicked")
            }
        case .sync:
            print("calibration save clicked")
            var isSaved = false
            let controller: UIAlertController

            if let params = newParams {
                do {
                    try self.cgmManager?.keychain.setLibreCalibrationData(params)
                    isSaved = true
                } catch {
                    print("error: \(error.localizedDescription)")
                }
            }

            if isSaved {
                controller = OKAlertController("Calibrations saved!", title: "ok")
            } else {
                controller = ErrorAlertController("Calibrations could not be saved, Check that footer crc is non-zero and that all values have sane defaults", title: "calibration error")
            }

            self.present(controller, animated: false)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
