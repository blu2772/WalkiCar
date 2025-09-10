//
//  ShortcutTemplateGenerator.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import UIKit

class ShortcutTemplateGenerator {
    static let shared = ShortcutTemplateGenerator()
    
    private init() {}
    
    // MARK: - Template Creation
    
    func createBluetoothConnectedTemplate(carId: Int, carName: String) -> String {
        let template = """
        {
          "WFWorkflowActions": [
            {
              "WFWorkflowActionIdentifier": "is.workflow.actions.openurl",
              "WFWorkflowActionParameters": {
                "WFURLActionURL": "walkicar://bluetooth/connected?carId=\(carId)"
              }
            },
            {
              "WFWorkflowActionIdentifier": "is.workflow.actions.notification",
              "WFWorkflowActionParameters": {
                "WFNotificationActionTitle": "WalkiCar",
                "WFNotificationActionBody": "\(carName) verbunden - Standort-Tracking gestartet"
              }
            }
          ],
          "WFWorkflowClientVersion": "900",
          "WFWorkflowMinimumClientVersion": 900,
          "WFWorkflowIcon": {
            "WFWorkflowIconStartColor": 4278190080,
            "WFWorkflowIconGlyphNumber": 57520
          }
        }
        """
        return template
    }
    
    func createBluetoothDisconnectedTemplate(carId: Int, carName: String) -> String {
        let template = """
        {
          "WFWorkflowActions": [
            {
              "WFWorkflowActionIdentifier": "is.workflow.actions.openurl",
              "WFWorkflowActionParameters": {
                "WFURLActionURL": "walkicar://bluetooth/disconnected?carId=\(carId)"
              }
            },
            {
              "WFWorkflowActionIdentifier": "is.workflow.actions.notification",
              "WFWorkflowActionParameters": {
                "WFNotificationActionTitle": "WalkiCar",
                "WFNotificationActionBody": "\(carName) getrennt - Standort-Tracking gestoppt"
              }
            }
          ],
          "WFWorkflowClientVersion": "900",
          "WFWorkflowMinimumClientVersion": 900,
          "WFWorkflowIcon": {
            "WFWorkflowIconStartColor": 16711680,
            "WFWorkflowIconGlyphNumber": 57520
          }
        }
        """
        return template
    }
    
    // MARK: - File Management
    
    func saveTemplateToFile(_ template: String, filename: String) -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let templateURL = documentsPath.appendingPathComponent("\(filename).shortcut")
        
        do {
            try template.write(to: templateURL, atomically: true, encoding: .utf8)
            return templateURL
        } catch {
            print("❌ ShortcutTemplateGenerator: Fehler beim Speichern: \(error)")
            return nil
        }
    }
    
    func createConnectedTemplateFile(carId: Int, carName: String) -> URL? {
        let template = createBluetoothConnectedTemplate(carId: carId, carName: carName)
        let filename = "WalkiCar_\(carName)_Verbunden"
        return saveTemplateToFile(template, filename: filename)
    }
    
    func createDisconnectedTemplateFile(carId: Int, carName: String) -> URL? {
        let template = createBluetoothDisconnectedTemplate(carId: carId, carName: carName)
        let filename = "WalkiCar_\(carName)_Getrennt"
        return saveTemplateToFile(template, filename: filename)
    }
    
    // MARK: - Share Integration
    
    func shareTemplates(for carId: Int, carName: String, from viewController: UIViewController) {
        guard let connectedURL = createConnectedTemplateFile(carId: carId, carName: carName),
              let disconnectedURL = createDisconnectedTemplateFile(carId: carId, carName: carName) else {
            print("❌ ShortcutTemplateGenerator: Fehler beim Erstellen der Templates")
            return
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [connectedURL, disconnectedURL],
            applicationActivities: nil
        )
        
        // Für iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
    }
}
