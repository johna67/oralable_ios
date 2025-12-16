//
//  RegulatoryModels.swift
//  OralableApp
//
//  Created: December 15, 2025
//  Purpose: Data models for regulatory pre-submission packages (FDA 510(k), CE Mark)
//  Provides structured data for compliance reports, validation results, and risk assessments
//

import Foundation

// MARK: - Regulatory Scope

/// Defines the regulatory framework scope for compliance reports
enum RegulatoryScope: String, Codable, CaseIterable {
    case fda510k = "FDA_510K"
    case ceMark = "CE_MARK"
    case both = "FDA_510K_AND_CE_MARK"

    var displayName: String {
        switch self {
        case .fda510k:
            return "FDA 510(k) Pre-Market Notification"
        case .ceMark:
            return "CE Mark (EU MDR)"
        case .both:
            return "FDA 510(k) and CE Mark"
        }
    }

    var regulatoryBody: String {
        switch self {
        case .fda510k:
            return "U.S. Food and Drug Administration"
        case .ceMark:
            return "European Notified Body"
        case .both:
            return "FDA and EU Notified Body"
        }
    }
}

// MARK: - Validation Outcome

/// Outcome of a validation test
enum ValidationOutcome: String, Codable {
    case pass = "PASS"
    case fail = "FAIL"
    case warning = "WARNING"
    case notApplicable = "NOT_APPLICABLE"
    case pending = "PENDING"

    var isAcceptable: Bool {
        switch self {
        case .pass, .notApplicable:
            return true
        case .fail, .warning, .pending:
            return false
        }
    }
}

// MARK: - Risk Severity

/// Severity level for risk assessments (ISO 14971 compliant)
enum RiskSeverity: Int, Codable, CaseIterable, Comparable {
    case negligible = 1
    case minor = 2
    case moderate = 3
    case major = 4
    case catastrophic = 5

    var displayName: String {
        switch self {
        case .negligible: return "Negligible"
        case .minor: return "Minor"
        case .moderate: return "Moderate"
        case .major: return "Major"
        case .catastrophic: return "Catastrophic"
        }
    }

    static func < (lhs: RiskSeverity, rhs: RiskSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Risk Likelihood

/// Likelihood of risk occurrence (ISO 14971 compliant)
enum RiskLikelihood: Int, Codable, CaseIterable, Comparable {
    case improbable = 1
    case remote = 2
    case occasional = 3
    case probable = 4
    case frequent = 5

    var displayName: String {
        switch self {
        case .improbable: return "Improbable"
        case .remote: return "Remote"
        case .occasional: return "Occasional"
        case .probable: return "Probable"
        case .frequent: return "Frequent"
        }
    }

    static func < (lhs: RiskLikelihood, rhs: RiskLikelihood) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Risk Level

/// Combined risk level based on severity and likelihood
enum RiskLevel: String, Codable {
    case acceptable = "ACCEPTABLE"
    case alarp = "ALARP" // As Low As Reasonably Practicable
    case unacceptable = "UNACCEPTABLE"

    var requiresMitigation: Bool {
        switch self {
        case .acceptable:
            return false
        case .alarp, .unacceptable:
            return true
        }
    }
}

// MARK: - Regulatory Validation Result

/// Represents the result of a single validation test for regulatory compliance
struct RegulatoryValidationResult: Codable, Identifiable, Equatable {
    let id: UUID
    let testName: String
    let testCategory: String
    let outcome: ValidationOutcome
    let timestamp: Date
    let notes: String?
    let testFilePath: String?
    let testLineNumber: Int?

    init(
        id: UUID = UUID(),
        testName: String,
        testCategory: String,
        outcome: ValidationOutcome,
        timestamp: Date = Date(),
        notes: String? = nil,
        testFilePath: String? = nil,
        testLineNumber: Int? = nil
    ) {
        self.id = id
        self.testName = testName
        self.testCategory = testCategory
        self.outcome = outcome
        self.timestamp = timestamp
        self.notes = notes
        self.testFilePath = testFilePath
        self.testLineNumber = testLineNumber
    }

    /// Formatted timestamp for reports
    var formattedTimestamp: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: timestamp)
    }

    /// CSV row representation
    var csvRow: String {
        let escapedNotes = (notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(testName)\",\"\(testCategory)\",\"\(outcome.rawValue)\",\"\(formattedTimestamp)\",\"\(escapedNotes)\""
    }
}

// MARK: - Risk Assessment

/// Represents a risk assessment entry (ISO 14971 compliant)
struct RiskAssessment: Codable, Identifiable, Equatable {
    let id: UUID
    let riskId: String
    let description: String
    let hazard: String
    let hazardousSituation: String
    let harm: String
    let severity: RiskSeverity
    let likelihood: RiskLikelihood
    let riskLevel: RiskLevel
    let mitigationSteps: [String]
    let residualRiskLevel: RiskLevel?
    let verificationMethod: String?
    let dateIdentified: Date
    let dateLastReviewed: Date

    init(
        id: UUID = UUID(),
        riskId: String,
        description: String,
        hazard: String,
        hazardousSituation: String,
        harm: String,
        severity: RiskSeverity,
        likelihood: RiskLikelihood,
        mitigationSteps: [String] = [],
        residualRiskLevel: RiskLevel? = nil,
        verificationMethod: String? = nil,
        dateIdentified: Date = Date(),
        dateLastReviewed: Date = Date()
    ) {
        self.id = id
        self.riskId = riskId
        self.description = description
        self.hazard = hazard
        self.hazardousSituation = hazardousSituation
        self.harm = harm
        self.severity = severity
        self.likelihood = likelihood
        self.riskLevel = Self.calculateRiskLevel(severity: severity, likelihood: likelihood)
        self.mitigationSteps = mitigationSteps
        self.residualRiskLevel = residualRiskLevel
        self.verificationMethod = verificationMethod
        self.dateIdentified = dateIdentified
        self.dateLastReviewed = dateLastReviewed
    }

    /// Calculate risk level from severity and likelihood (ISO 14971 risk matrix)
    static func calculateRiskLevel(severity: RiskSeverity, likelihood: RiskLikelihood) -> RiskLevel {
        let riskScore = severity.rawValue * likelihood.rawValue

        switch riskScore {
        case 1...4:
            return .acceptable
        case 5...12:
            return .alarp
        default:
            return .unacceptable
        }
    }

    /// Risk priority number for sorting
    var riskPriorityNumber: Int {
        severity.rawValue * likelihood.rawValue
    }

    /// CSV row representation
    var csvRow: String {
        let mitigationString = mitigationSteps.joined(separator: "; ")
        return "\"\(riskId)\",\"\(description)\",\"\(hazard)\",\"\(severity.displayName)\",\"\(likelihood.displayName)\",\"\(riskLevel.rawValue)\",\"\(mitigationString)\""
    }
}

// MARK: - Compliance Finding

/// Represents a compliance finding or observation
struct ComplianceFinding: Codable, Identifiable, Equatable {
    let id: UUID
    let findingId: String
    let category: ComplianceFindingCategory
    let description: String
    let requirement: String
    let status: ComplianceFindingStatus
    let evidence: String?
    let recommendation: String?
    let dateIdentified: Date
    let dateResolved: Date?

    init(
        id: UUID = UUID(),
        findingId: String,
        category: ComplianceFindingCategory,
        description: String,
        requirement: String,
        status: ComplianceFindingStatus,
        evidence: String? = nil,
        recommendation: String? = nil,
        dateIdentified: Date = Date(),
        dateResolved: Date? = nil
    ) {
        self.id = id
        self.findingId = findingId
        self.category = category
        self.description = description
        self.requirement = requirement
        self.status = status
        self.evidence = evidence
        self.recommendation = recommendation
        self.dateIdentified = dateIdentified
        self.dateResolved = dateResolved
    }
}

/// Category of compliance finding
enum ComplianceFindingCategory: String, Codable, CaseIterable {
    case softwareRequirements = "SOFTWARE_REQUIREMENTS"
    case verification = "VERIFICATION"
    case validation = "VALIDATION"
    case riskManagement = "RISK_MANAGEMENT"
    case documentation = "DOCUMENTATION"
    case labeling = "LABELING"
    case cybersecurity = "CYBERSECURITY"
    case usability = "USABILITY"

    var displayName: String {
        switch self {
        case .softwareRequirements: return "Software Requirements"
        case .verification: return "Verification"
        case .validation: return "Validation"
        case .riskManagement: return "Risk Management"
        case .documentation: return "Documentation"
        case .labeling: return "Labeling"
        case .cybersecurity: return "Cybersecurity"
        case .usability: return "Usability"
        }
    }
}

/// Status of a compliance finding
enum ComplianceFindingStatus: String, Codable {
    case open = "OPEN"
    case inProgress = "IN_PROGRESS"
    case resolved = "RESOLVED"
    case accepted = "ACCEPTED"
    case notApplicable = "NOT_APPLICABLE"
}

// MARK: - Compliance Report

/// Complete compliance report for regulatory submission
struct ComplianceReport: Codable, Identifiable {
    let id: UUID
    let reportId: String
    let dateGenerated: Date
    let scope: RegulatoryScope
    let deviceName: String
    let deviceVersion: String
    let manufacturer: String
    let findings: [ComplianceFinding]
    let recommendations: [String]
    let validationResults: [RegulatoryValidationResult]
    let riskAssessments: [RiskAssessment]
    let softwareVersion: String
    let documentVersion: String
    let preparedBy: String?
    let reviewedBy: String?

    init(
        id: UUID = UUID(),
        reportId: String,
        dateGenerated: Date = Date(),
        scope: RegulatoryScope,
        deviceName: String,
        deviceVersion: String,
        manufacturer: String,
        findings: [ComplianceFinding] = [],
        recommendations: [String] = [],
        validationResults: [RegulatoryValidationResult] = [],
        riskAssessments: [RiskAssessment] = [],
        softwareVersion: String,
        documentVersion: String = "1.0",
        preparedBy: String? = nil,
        reviewedBy: String? = nil
    ) {
        self.id = id
        self.reportId = reportId
        self.dateGenerated = dateGenerated
        self.scope = scope
        self.deviceName = deviceName
        self.deviceVersion = deviceVersion
        self.manufacturer = manufacturer
        self.findings = findings
        self.recommendations = recommendations
        self.validationResults = validationResults
        self.riskAssessments = riskAssessments
        self.softwareVersion = softwareVersion
        self.documentVersion = documentVersion
        self.preparedBy = preparedBy
        self.reviewedBy = reviewedBy
    }

    // MARK: - Computed Properties

    /// Overall compliance status
    var overallStatus: ComplianceStatus {
        let hasUnresolvedFindings = findings.contains {
            $0.status == .open || $0.status == .inProgress
        }
        let hasFailedValidations = validationResults.contains {
            $0.outcome == .fail
        }
        let hasUnacceptableRisks = riskAssessments.contains {
            $0.riskLevel == .unacceptable && $0.residualRiskLevel != .acceptable && $0.residualRiskLevel != .alarp
        }

        if hasUnacceptableRisks {
            return .notCompliant
        } else if hasFailedValidations || hasUnresolvedFindings {
            return .partiallyCompliant
        } else {
            return .compliant
        }
    }

    /// Summary statistics
    var summary: ComplianceReportSummary {
        ComplianceReportSummary(
            totalFindings: findings.count,
            openFindings: findings.filter { $0.status == .open }.count,
            resolvedFindings: findings.filter { $0.status == .resolved }.count,
            totalValidations: validationResults.count,
            passedValidations: validationResults.filter { $0.outcome == .pass }.count,
            failedValidations: validationResults.filter { $0.outcome == .fail }.count,
            totalRisks: riskAssessments.count,
            acceptableRisks: riskAssessments.filter { $0.riskLevel == .acceptable }.count,
            unacceptableRisks: riskAssessments.filter { $0.riskLevel == .unacceptable }.count
        )
    }

    /// Formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: dateGenerated)
    }

    /// ISO 8601 formatted date
    var isoDate: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: dateGenerated)
    }
}

/// Overall compliance status
enum ComplianceStatus: String, Codable {
    case compliant = "COMPLIANT"
    case partiallyCompliant = "PARTIALLY_COMPLIANT"
    case notCompliant = "NOT_COMPLIANT"
    case underReview = "UNDER_REVIEW"
}

/// Summary statistics for compliance report
struct ComplianceReportSummary: Codable {
    let totalFindings: Int
    let openFindings: Int
    let resolvedFindings: Int
    let totalValidations: Int
    let passedValidations: Int
    let failedValidations: Int
    let totalRisks: Int
    let acceptableRisks: Int
    let unacceptableRisks: Int

    var validationPassRate: Double {
        guard totalValidations > 0 else { return 0 }
        return Double(passedValidations) / Double(totalValidations) * 100
    }

    var riskMitigationRate: Double {
        guard totalRisks > 0 else { return 0 }
        return Double(acceptableRisks) / Double(totalRisks) * 100
    }
}

// MARK: - Export Formats

/// Export format options for regulatory reports
enum RegulatoryExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"
    case xml = "XML"

    var fileExtension: String {
        rawValue.lowercased()
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .pdf: return "application/pdf"
        case .xml: return "application/xml"
        }
    }
}
