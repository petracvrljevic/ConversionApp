//
//  MainViewController.swift
//  ConversionApp
//
//  Created by Petra Cvrljevic on 24/08/2018.
//  Copyright © 2018 Petra Cvrljevic. All rights reserved.
//

import UIKit
import Alamofire
import CoreData
import SwiftyJSON
import MBProgressHUD

class MainViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var fromCurrencyPicker: UIPickerView!
    @IBOutlet weak var toCurrencyPicker: UIPickerView!
    @IBOutlet weak var currencyValue: UITextField!
    @IBOutlet weak var rateSegmentedControl: UISegmentedControl!
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var currencyCodes = [String]()
    var currencys = [Currency]()
    
    var fromCode = ""
    var toCode = ""
    var selectedRate : Rate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fromCurrencyPicker.delegate = self
        fromCurrencyPicker.dataSource = self
        toCurrencyPicker.delegate = self
        toCurrencyPicker.dataSource = self
        
        currencyValue.delegate = self

        if firstAppLaunch() {
            deleteData()
            downloadCurrencys()
        }
        else {
            getCurrencysFromCoreData()
        }
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: Notification.Name.UIKeyboardWillHide, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
        
    }
    
    @objc func adjustForKeyboard(notification: Notification) {
        
        if notification.name == Notification.Name.UIKeyboardWillHide {
            self.scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
        }
        else {
            let bottomOffSet = CGPoint(x: 0, y: self.scrollView.contentSize.height - self.scrollView.bounds.size.height + self.scrollView.contentInset.bottom)
            self.scrollView.setContentOffset(bottomOffSet, animated: true)
        }
        
    }
    
    func firstAppLaunch() -> Bool {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let todayString = formatter.string(from: today)
        
        if UserDefaults.standard.string(forKey: "today") == todayString {
            return false
        }
        else {
            UserDefaults.standard.setValue(todayString, forKey: "today")
            return true
        }
    }
    
    func downloadCurrencys() {
        
        MBProgressHUD.showAdded(to: self.view, animated: true)
        
        let apiURL = URL(string: "http://hnbex.eu/api/v1/rates/daily")
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let entity = NSEntityDescription.entity(forEntityName: "Currency", in: context)
        
        Alamofire.request(apiURL!, method: .get).responseJSON { (response) in
            
            MBProgressHUD.hide(for: self.view, animated: true)
            
            if response.result.isSuccess {
                let currencys = JSON(response.result.value!).arrayObject as [AnyObject]?
                if let currencys = currencys {
                    for currency in currencys {
                        let newCurrency = NSManagedObject(entity: entity!, insertInto: context)
                        newCurrency.setValue(currency["currency_code"] as! String, forKey: "currency_code")
                        newCurrency.setValue(currency["unit_value"] as! Int, forKey: "unit_value")
                        newCurrency.setValue(currency["median_rate"] as! String, forKey: "median_rate")
                        newCurrency.setValue(currency["selling_rate"] as! String, forKey: "selling_rate")
                        newCurrency.setValue(currency["buying_rate"] as! String, forKey: "buying_rate")
                    }
                    
                    do {
                        try context.save()
                        print("Saved")
                    }
                    catch {
                        print("Failed saving")
                    }
                    
                    self.getCurrencysFromCoreData()
                }
            }
        }
    }
    
    func getCurrencysFromCoreData() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Currency")
        request.returnsObjectsAsFaults = false
        do {
            let result = try context.fetch(request)
            self.currencys = (result as? [Currency])!
            
        } catch {
            print("Failed")
        }
        
        for currency in currencys {
            currencyCodes.append(currency.currency_code!)
        }
        
        currencyCodes.sort { $0 < $1 }
        fromCode = currencyCodes[0]
        toCode = currencyCodes[0]
        
        self.fromCurrencyPicker.reloadAllComponents()
        self.toCurrencyPicker.reloadAllComponents()
    }
    
    func deleteData() {
        
        let appDel:AppDelegate = (UIApplication.shared.delegate as! AppDelegate)
        let context:NSManagedObjectContext = appDel.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Currency")
        fetchRequest.returnsObjectsAsFaults = false
        
        do
        {
            let results = try context.fetch(fetchRequest)
            for managedObject in results {
                let managedObjectData:NSManagedObject = managedObject as! NSManagedObject
                context.delete(managedObjectData)
            }
        } catch let error as NSError {
            print("Error : \(error) \(error.userInfo)")
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return currencyCodes.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return currencyCodes[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == fromCurrencyPicker {
            fromCode = currencyCodes[row]
        }
        else {
            toCode = currencyCodes[row]
        }
        resultLabel.text = "0"
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        currencyValue.resignFirstResponder()
        return true
    }
    
    @IBAction func submit(_ sender: UIButton) {
        
        let fromCurrency = currencys.filter { (currency) -> Bool in
            return currency.currency_code == fromCode
        }
        
        let toCurrency = currencys.filter { (currency) -> Bool in
            return currency.currency_code == toCode
        }
        
        selectedRate = rateSegmentedControl.selectedSegmentIndex == 0 ? Rate.buying : .selling
        
        if !((currencyValue.text?.isEmpty)!  && !currencys.isEmpty) {
            let value = Double(currencyValue.text!)
            
            let fromRate: Double
            let toRate: Double
            
            let fromUnit = Double((fromCurrency.first?.unit_value)!)
            let toUnit = Double((toCurrency.first?.unit_value)!)
            
            switch selectedRate! {
            case .buying:
                fromRate = fromUnit != 1 ? (Double((fromCurrency.first?.buying_rate)!)! / fromUnit) : Double((fromCurrency.first?.buying_rate)!)!
                
                toRate = toUnit != 1 ? (Double((toCurrency.first?.buying_rate)!)! / toUnit): Double((toCurrency.first?.buying_rate)!)!
            case .selling:
                fromRate = fromUnit != 1 ? (Double((fromCurrency.first?.selling_rate)!)! / fromUnit) : Double((fromCurrency.first?.selling_rate)!)!
                
                toRate = toUnit != 1 ? (Double((toCurrency.first?.selling_rate)!)! / toUnit): Double((toCurrency.first?.selling_rate)!)!
            }
            
            
            let result = ((value!*fromRate)/toRate)
            resultLabel.text = "\(value!) " + fromCode + " = " + " \(result) " + toCode
        }
        else {
            let alertController = UIAlertController(title: "Warning", message: "You need to enter value!", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
        
    }
    
    enum Rate {
        case buying
        case selling
    }    
}
