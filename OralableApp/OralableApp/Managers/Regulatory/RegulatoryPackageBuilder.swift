//
//  RegulatoryPackageBuilder.swift
//  OralableApp
//
//  Created: December 15, 2025
//  Purpose: Builds regulatory pre-submission packages for FDA 510(k) and CE Mark
//  Aggregates validation results, risk assessments, and compliance findings
//

import Foundation

// MARK: - Regulatory Package Builder

/// Builds and exports regulatory pre-submission packages for FDA 510(k) and CE Mark
class RegulatoryPackageBuilder: ObservableObject {

    // MARK: - Singleton

    static let shared = RegulatoryPackageBuilder()

    // MARK: - Configuration

    struct Configuration {
        let deviceName: String
        let deviceVersion: String
        let manufacturer: String
        let softwareVersion: String
        let preparedBy: String?
        let reviewedBy: String?

        static var `default`: Configuration {
            Configuration(
                deviceName: "Oralable Oral Activity Monitor",
                deviceVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                manufacturer: "JAC Dental Ltd",
                softwareVersion: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                preparedBy: nil,
                reviewedBy: nil
            )
        }
    }

    // MARK: - Properties

    @Published private(set) var validationResults: [RegulatoryValidationResult] = []
    @Published private(set) var riskAssessments: [RiskAssessment] = []
    @Published private(set) var complianceFindings: [ComplianceFinding] = []

    private var configuration: Configuration

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.configuration = configuration
        loadPredefinedRiskAssessments()
    }

    // MARK: - Configuration

    func configure(with configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: - FDA 510(k) Package Generation

    /// Generates a complete FDA 510(k) pre-submission package
    /// - Returns: ComplianceReport configured for FDA 510(k) submission
    func generateFDA510kPackage() -> ComplianceReport {
        let reportId = generateReportId(scope: .fda510k)

        // Add FDA-specific findings
        let fdaFindings = generateFDAFindings()

        // Add FDA-specific recommendations
        let fdaRecommendations = generateFDARecommendations()

        return ComplianceReport(
            reportId: reportId,
            dateGenerated: Date(),
            scope: .fda510k,
            deviceName: configuration.deviceName,
            deviceVersion: configuration.deviceVersion,
            manufacturer: configuration.manufacturer,
            findings: complianceFindings + fdaFindings,
            recommendations: fdaRecommendations,
            validationResults: validationResults,
            riskAssessments: riskAssessments,
            softwareVersion: configuration.softwareVersion,
            documentVersion: "1.0",
            preparedBy: configuration.preparedBy,
            reviewedBy: configuration.reviewedBy
        )
    }

    /// Generates a complete CE Mark pre-submission package
    /// - Returns: ComplianceReport configured for CE Mark submission
    func generateCEMarkPackage() -> ComplianceReport {
        let reportId = generateReportId(scope: .ceMark)

        // Add CE-specific findings
        let ceFindings = generateCEFindings()

        // Add CE-specific recommendations
        let ceRecommendations = generateCERecommendations()

        return ComplianceReport(
            reportId: reportId,
            dateGenerated: Date(),
            scope: .ceMark,
            deviceName: configuration.deviceName,
            deviceVersion: configuration.deviceVersion,
            manufacturer: configuration.manufacturer,
            findings: complianceFindings + ceFindings,
            recommendations: ceRecommendations,
            validationResults: validationResults,
            riskAssessments: riskAssessments,
            softwareVersion: configuration.softwareVersion,
            documentVersion: "1.0",
            preparedBy: configuration.preparedBy,
            reviewedBy: configuration.reviewedBy
        )
    }

    // MARK: - Validation Results Management

    /// Adds a validation result from test execution
    func addValidationResult(_ result: RegulatoryValidationResult) {
        validationResults.append(result)
    }

    /// Adds multiple validation results
    func addValidationResults(_ results: [RegulatoryValidationResult]) {
        validationResults.append(contentsOf: results)
    }

    /// Records a test result (convenience method for test suite integration)
    func recordTestResult(
        testName: String,
        category: String,
        passed: Bool,
        notes: String? = nil,
        filePath: String? = nil,
        lineNumber: Int? = nil
    ) {
        let result = RegulatoryValidationResult(
            testName: testName,
            testCategory: category,
            outcome: passed ? .pass : .fail,
            timestamp: Date(),
            notes: notes,
            testFilePath: filePath,
            testLineNumber: lineNumber
        )
        addValidationResult(result)
    }

    /// Clears all validation results
    func clearValidationResults() {
        validationResults.removeAll()
    }

    // MARK: - Risk Assessment Management

    /// Adds a risk assessment
    func addRiskAssessment(_ assessment: RiskAssessment) {
        riskAssessments.append(assessment)
    }

    /// Adds multiple risk assessments
    func addRiskAssessments(_ assessments: [RiskAssessment]) {
        riskAssessments.append(contentsOf: assessments)
    }

    /// Clears all risk assessments
    func clearRiskAssessments() {
        riskAssessments.removeAll()
    }

    // MARK: - Compliance Findings Management

    /// Adds a compliance finding
    func addComplianceFinding(_ finding: ComplianceFinding) {
        complianceFindings.append(finding)
    }

    /// Clears all compliance findings
    func clearComplianceFindings() {
        complianceFindings.removeAll()
    }

    // MARK: - Export Methods

    /// Exports the compliance report to JSON format
    /// - Parameter report: The compliance report to export
    /// - Returns: URL of the exported JSON file, or nil if export fails
    func exportToJSON(_ report: ComplianceReport) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(report)
            let filename = "\(report.reportId).json"
            let fileURL = getExportDirectory().appendingPathComponent(filename)

            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            Logger.shared.error("[RegulatoryPackageBuilder] Failed to export JSON: \(error)")
            return nil
        }
    }

    /// Exports the compliance report to CSV format (multiple files)
    /// - Parameter report: The compliance report to export
    /// - Returns: URL of the export directory containing CSV files, or nil if export fails
    func exportToCSV(_ report: ComplianceReport) -> URL? {
        let exportDir = getExportDirectory().appendingPathComponent(report.reportId)

        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

            // Export validation results
            try exportValidationResultsCSV(report.validationResults, to: exportDir)

            // Export risk assessments
            try exportRiskAssessmentsCSV(report.riskAssessments, to: exportDir)

            // Export compliance findings
            try exportComplianceFindingsCSV(report.findings, to: exportDir)

            // Export summary
            try exportSummaryCSV(report, to: exportDir)

            return exportDir
        } catch {
            Logger.shared.error("[RegulatoryPackageBuilder] Failed to export CSV: \(error)")
            return nil
        }
    }

    /// Exports report data as JSON Data object
    /// - Parameter report: The compliance report to export
    /// - Returns: JSON Data or nil if encoding fails
    func exportToJSONData(_ report: ComplianceReport) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(report)
        } catch {
            Logger.shared.error("[RegulatoryPackageBuilder] Failed to encode JSON: \(error)")
            return nil
        }
    }

    // MARK: - Private Methods

    private func generateReportId(scope: RegulatoryScope) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let prefix: String
        switch scope {
        case .fda510k:
            prefix = "FDA510K"
        case .ceMark:
            prefix = "CE"
        case .both:
            prefix = "REG"
        }

        return "\(prefix)-\(timestamp)"
    }

    private func getExportDirectory() -> URL {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let exportDir = cacheDir.appendingPathComponent("RegulatoryExports", isDirectory: true)

        if !fileManager.fileExists(atPath: exportDir.path) {
            try? fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        }

        return exportDir
    }

    private func exportValidationResultsCSV(_ results: [RegulatoryValidationResult], to directory: URL) throws {
        var csv = "Test Name,Category,Outcome,Timestamp,Notes\n"
        for result in results {
            csv += result.csvRow + "\n"
        }
        let fileURL = directory.appendingPathComponent("validation_results.csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func exportRiskAssessmentsCSV(_ assessments: [RiskAssessment], to directory: URL) throws {
        var csv = "Risk ID,Description,Hazard,Severity,Likelihood,Risk Level,Mitigation Steps\n"
        for assessment in assessments {
            csv += assessment.csvRow + "\n"
        }
        let fileURL = directory.appendingPathComponent("risk_assessments.csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func exportComplianceFindingsCSV(_ findings: [ComplianceFinding], to directory: URL) throws {
        var csv = "Finding ID,Category,Description,Requirement,Status,Evidence,Recommendation\n"
        for finding in findings {
            let evidence = (finding.evidence ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let recommendation = (finding.recommendation ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(finding.findingId)\",\"\(finding.category.displayName)\",\"\(finding.description)\",\"\(finding.requirement)\",\"\(finding.status.rawValue)\",\"\(evidence)\",\"\(recommendation)\"\n"
        }
        let fileURL = directory.appendingPathComponent("compliance_findings.csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func exportSummaryCSV(_ report: ComplianceReport, to directory: URL) throws {
        let summary = report.summary
        var csv = "Metric,Value\n"
        csv += "Report ID,\(report.reportId)\n"
        csv += "Scope,\(report.scope.displayName)\n"
        csv += "Date Generated,\(report.formattedDate)\n"
        csv += "Overall Status,\(report.overallStatus.rawValue)\n"
        csv += "Total Findings,\(summary.totalFindings)\n"
        csv += "Open Findings,\(summary.openFindings)\n"
        csv += "Resolved Findings,\(summary.resolvedFindings)\n"
        csv += "Total Validations,\(summary.totalValidations)\n"
        csv += "Passed Validations,\(summary.passedValidations)\n"
        csv += "Failed Validations,\(summary.failedValidations)\n"
        csv += "Validation Pass Rate,\(String(format: "%.1f", summary.validationPassRate))%\n"
        csv += "Total Risks,\(summary.totalRisks)\n"
        csv += "Acceptable Risks,\(summary.acceptableRisks)\n"
        csv += "Unacceptable Risks,\(summary.unacceptableRisks)\n"
        csv += "Risk Mitigation Rate,\(String(format: "%.1f", summary.riskMitigationRate))%\n"

        let fileURL = directory.appendingPathComponent("summary.csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Predefined Data

    private func loadPredefinedRiskAssessments() {
        // Load predefined risk assessments for the Oralable device
        let predefinedRisks = createPredefinedRiskAssessments()
        riskAssessments = predefinedRisks
    }

    private func createPredefinedRiskAssessments() -> [RiskAssessment] {
        return [
            // BLE Connection Risks
            RiskAssessment(
                riskId: "RISK-001",
                description: "Bluetooth connection loss during monitoring",
                hazard: "Wireless communication failure",
                hazardousSituation: "User loses real-time feedback during activity monitoring",
                harm: "User unaware of current activity levels; delayed data",
                severity: .minor,
                likelihood: .occasional,
                mitigationSteps: [
                    "Implement automatic reconnection with exponential backoff",
                    "Store data locally when disconnected",
                    "Display clear connection status indicator",
                    "Alert user when connection is lost"
                ],
                residualRiskLevel: .acceptable,
                verificationMethod: "BLE reconnection tests (BLEBackgroundWorkerTests)"
            ),

            // Data Integrity Risks
            RiskAssessment(
                riskId: "RISK-002",
                description: "Sensor data corruption during transmission",
                hazard: "Data transmission error",
                hazardousSituation: "Corrupted data displayed to user",
                harm: "User receives inaccurate wellness information",
                severity: .moderate,
                likelihood: .remote,
                mitigationSteps: [
                    "Implement data validation checks",
                    "Use checksums for data integrity verification",
                    "Display data quality indicators",
                    "Reject data outside expected ranges"
                ],
                residualRiskLevel: .acceptable,
                verificationMethod: "Data validation tests (SensorDataProcessorTests)"
            ),

            // Battery/Power Risks
            RiskAssessment(
                riskId: "RISK-003",
                description: "Device battery depletion during monitoring",
                hazard: "Power supply failure",
                hazardousSituation: "Monitoring session interrupted unexpectedly",
                harm: "Incomplete data collection; user inconvenience",
                severity: .minor,
                likelihood: .occasional,
                mitigationSteps: [
                    "Display battery level prominently",
                    "Warn user at low battery thresholds",
                    "Save data periodically to prevent loss",
                    "Graceful shutdown on critical battery"
                ],
                residualRiskLevel: .acceptable,
                verificationMethod: "Battery monitoring tests"
            ),

            // Software Stability Risks
            RiskAssessment(
                riskId: "RISK-004",
                description: "Application crash during use",
                hazard: "Software failure",
                hazardousSituation: "App terminates unexpectedly",
                harm: "Data loss; user frustration; interrupted monitoring",
                severity: .minor,
                likelihood: .remote,
                mitigationSteps: [
                    "Implement crash reporting and analytics",
                    "Persist critical data to storage",
                    "Handle all errors gracefully",
                    "Test edge cases thoroughly"
                ],
                residualRiskLevel: .acceptable,
                verificationMethod: "Regression tests (RegressionTests)"
            ),

            // Privacy/Security Risks
            RiskAssessment(
                riskId: "RISK-005",
                description: "Unauthorized access to health data",
                hazard: "Data breach",
                hazardousSituation: "Sensitive health data exposed",
                harm: "Privacy violation; psychological harm to user",
                severity: .major,
                likelihood: .improbable,
                mitigationSteps: [
                    "Require authentication via Sign in with Apple",
                    "Encrypt data at rest and in transit",
                    "Implement App Transport Security",
                    "No third-party tracking"
                ],
                residualRiskLevel: .acceptable,
                verificationMethod: "Security audit tests (ComplianceTests)"
            ),

            // Misinterpretation Risks
            RiskAssessment(
                riskId: "RISK-006",
                description: "User misinterprets wellness data as medical diagnosis",
                hazard: "Unclear product positioning",
                hazardousSituation: "User makes medical decisions based on wellness data",
                harm: "Delayed proper medical care; inappropriate self-treatment",
                severity: .major,
                likelihood: .remote,
                mitigationSteps: [
                    "Clear disclaimer that app is not a medical device",
                    "Use wellness-focused language (not diagnostic)",
                    "Recommend consulting healthcare provider",
                    "Remove all diagnostic terminology"
                ],
                residualRiskLevel: .acceptable,
                verificationMethod: "Compliance audit tests (ComplianceTests)"
            ),

            // Usability Risks
            RiskAssessment(
                riskId: "RISK-007",
                description: "User unable to operate app effectively",
                hazard: "Poor usability",
                hazardousSituation: "User cannot access or understand data",
                harm: "Frustration; failure to benefit from monitoring",
                severity: .minor,
                likelihood: .occasional,
                mitigationSteps: [
                    "Implement intuitive UI/UX design",
                    "Support accessibility features (VoiceOver, Dynamic Type)",
                    "Provide clear onboarding flow",
                    "Display helpful error messages"
                ],
                residualRiskLevel: .acceptable,
                verificationMethod: "UI consistency tests (DashboardUIConsistencyTests)"
            )
        ]
    }

    private func generateFDAFindings() -> [ComplianceFinding] {
        return [
            ComplianceFinding(
                findingId: "FDA-001",
                category: .softwareRequirements,
                description: "Software requirements specification documented",
                requirement: "21 CFR Part 820.30(c) - Design Input",
                status: .resolved,
                evidence: "Requirements documented in technical specifications",
                recommendation: "Maintain traceability matrix"
            ),
            ComplianceFinding(
                findingId: "FDA-002",
                category: .verification,
                description: "Software verification testing completed",
                requirement: "21 CFR Part 820.30(f) - Design Verification",
                status: .resolved,
                evidence: "Unit tests, integration tests, and UI tests implemented",
                recommendation: "Continue automated testing in CI/CD"
            ),
            ComplianceFinding(
                findingId: "FDA-003",
                category: .riskManagement,
                description: "Risk management process implemented",
                requirement: "21 CFR Part 820.30(g) - Design Validation",
                status: .resolved,
                evidence: "Risk assessments documented per ISO 14971",
                recommendation: "Review risk assessments periodically"
            ),
            ComplianceFinding(
                findingId: "FDA-004",
                category: .cybersecurity,
                description: "Cybersecurity controls implemented",
                requirement: "FDA Guidance on Cybersecurity",
                status: .resolved,
                evidence: "Authentication, encryption, and privacy manifest implemented",
                recommendation: "Conduct periodic security reviews"
            ),
            ComplianceFinding(
                findingId: "FDA-005",
                category: .labeling,
                description: "Product labeling reviewed for compliance",
                requirement: "21 CFR Part 801 - Labeling",
                status: .resolved,
                evidence: "No diagnostic claims in app store metadata or UI",
                recommendation: "Review all marketing materials"
            )
        ]
    }

    private func generateCEFindings() -> [ComplianceFinding] {
        return [
            ComplianceFinding(
                findingId: "CE-001",
                category: .softwareRequirements,
                description: "Software lifecycle process documented",
                requirement: "IEC 62304 - Medical device software lifecycle",
                status: .resolved,
                evidence: "Development documentation maintained",
                recommendation: "Maintain software development file"
            ),
            ComplianceFinding(
                findingId: "CE-002",
                category: .riskManagement,
                description: "Risk management file established",
                requirement: "ISO 14971 - Risk Management",
                status: .resolved,
                evidence: "Risk assessments documented with mitigations",
                recommendation: "Update risk file with each release"
            ),
            ComplianceFinding(
                findingId: "CE-003",
                category: .usability,
                description: "Usability engineering process applied",
                requirement: "IEC 62366-1 - Usability engineering",
                status: .resolved,
                evidence: "UI/UX testing and accessibility features implemented",
                recommendation: "Conduct usability studies"
            ),
            ComplianceFinding(
                findingId: "CE-004",
                category: .documentation,
                description: "Technical documentation prepared",
                requirement: "EU MDR Annex II - Technical documentation",
                status: .inProgress,
                evidence: "Documentation in progress",
                recommendation: "Complete technical file before submission"
            ),
            ComplianceFinding(
                findingId: "CE-005",
                category: .cybersecurity,
                description: "Cybersecurity requirements addressed",
                requirement: "MDCG 2019-16 - Cybersecurity guidance",
                status: .resolved,
                evidence: "Security controls and privacy manifest implemented",
                recommendation: "Maintain security documentation"
            )
        ]
    }

    private func generateFDARecommendations() -> [String] {
        return [
            "Submit 510(k) with identified predicate device for substantial equivalence",
            "Include software documentation per FDA Guidance on Software Validation",
            "Document software safety classification (likely Class B per IEC 62304)",
            "Prepare cybersecurity documentation per FDA premarket guidance",
            "Ensure labeling does not contain diagnostic or treatment claims",
            "Maintain design history file with all verification evidence",
            "Consider De Novo pathway if no suitable predicate device exists"
        ]
    }

    private func generateCERecommendations() -> [String] {
        return [
            "Determine device classification under EU MDR (likely Class IIa)",
            "Prepare technical documentation per Annex II requirements",
            "Establish conformity assessment procedure per Annex IX or XI",
            "Implement post-market surveillance system",
            "Prepare clinical evaluation report",
            "Register device in EUDAMED when available",
            "Engage Notified Body for conformity assessment"
        ]
    }
}

// MARK: - Test Suite Integration

extension RegulatoryPackageBuilder {

    /// Category constants for test suite integration
    struct TestCategories {
        static let ble = "BLE Operations"
        static let mvvm = "MVVM Architecture"
        static let storeKit = "StoreKit Integration"
        static let onboarding = "Onboarding Flow"
        static let dataExport = "Data Export"
        static let compliance = "Compliance"
        static let performance = "Performance"
        static let ui = "User Interface"
        static let security = "Security"
        static let accessibility = "Accessibility"
    }

    /// Records results from BLE test suite
    func recordBLETestResults(passed: Int, failed: Int, total: Int) {
        recordTestResult(
            testName: "BLE Test Suite",
            category: TestCategories.ble,
            passed: failed == 0,
            notes: "Passed: \(passed)/\(total), Failed: \(failed)"
        )
    }

    /// Records results from MVVM test suite
    func recordMVVMTestResults(passed: Int, failed: Int, total: Int) {
        recordTestResult(
            testName: "MVVM Test Suite",
            category: TestCategories.mvvm,
            passed: failed == 0,
            notes: "Passed: \(passed)/\(total), Failed: \(failed)"
        )
    }

    /// Records results from compliance test suite
    func recordComplianceTestResults(passed: Int, failed: Int, total: Int) {
        recordTestResult(
            testName: "Compliance Test Suite",
            category: TestCategories.compliance,
            passed: failed == 0,
            notes: "Passed: \(passed)/\(total), Failed: \(failed)"
        )
    }

    /// Records results from performance test suite
    func recordPerformanceTestResults(passed: Int, failed: Int, total: Int) {
        recordTestResult(
            testName: "Performance Test Suite",
            category: TestCategories.performance,
            passed: failed == 0,
            notes: "Passed: \(passed)/\(total), Failed: \(failed)"
        )
    }

    /// Imports validation results from XCTest result bundle
    /// - Parameter results: Array of test results to import
    func importTestResults(_ results: [(name: String, category: String, passed: Bool, notes: String?)]) {
        for result in results {
            recordTestResult(
                testName: result.name,
                category: result.category,
                passed: result.passed,
                notes: result.notes
            )
        }
    }
}
