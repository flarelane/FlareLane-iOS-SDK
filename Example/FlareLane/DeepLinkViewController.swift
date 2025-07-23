//
//  DeepLinkViewController.swift
//  FlareLane
//
//  Created for deep link testing
//

import UIKit

class DeepLinkViewController: UIViewController {
    
    @IBOutlet weak var deepLinkLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    
    var deepLinkURL: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateDeepLinkDisplay()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Create deep link label
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .label
        view.addSubview(label)
        self.deepLinkLabel = label
        
        // Create back button
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Back to Main", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(button)
        self.backButton = button
        
        // Setup constraints
        NSLayoutConstraint.activate([
            deepLinkLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deepLinkLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            deepLinkLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            deepLinkLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.topAnchor.constraint(equalTo: deepLinkLabel.bottomAnchor, constant: 30),
            backButton.widthAnchor.constraint(equalToConstant: 200),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func updateDeepLinkDisplay() {
        if let url = deepLinkURL {
            deepLinkLabel.text = "Deep Link Received:\n\(url)"
            deepLinkLabel.textColor = .systemGreen
        } else {
            deepLinkLabel.text = "No deep link received"
            deepLinkLabel.textColor = .systemRed
        }
    }
    
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
} 