//
// ParametricMapParser.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Parser for DICOM Parametric Map objects
///
/// Parses Parametric Map IODs from DICOM data sets, extracting real world value mappings,
/// quantity definitions, multi-frame pixel data properties, and functional groups.
///
/// Reference: PS3.3 A.75 - Parametric Map IOD
/// Reference: PS3.3 C.8.23 - Parametric Map Modules
/// Reference: PS3.3 C.7.6.16.2.11 - Real World Value Mapping Functional Group
public struct ParametricMapParser {
    
    /// Parse Parametric Map from a DICOM data set
    ///
    /// - Parameter dataSet: DICOM data set containing Parametric Map
    /// - Returns: Parsed Parametric Map
    /// - Throws: DICOMError if parsing fails
    public static func parse(from dataSet: DataSet) throws -> ParametricMap {
        // Parse SOP Instance UID and SOP Class UID
        guard let sopInstanceUID = dataSet.string(for: .sopInstanceUID) else {
            throw DICOMError.parsingFailed("Missing SOP Instance UID")
        }
        
        let sopClassUID = dataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.30"
        
        // Parse Series and Study UIDs
        guard let seriesInstanceUID = dataSet.string(for: .seriesInstanceUID) else {
            throw DICOMError.parsingFailed("Missing Series Instance UID")
        }
        
        guard let studyInstanceUID = dataSet.string(for: .studyInstanceUID) else {
            throw DICOMError.parsingFailed("Missing Study Instance UID")
        }
        
        // Parse Content Identification
        let instanceNumber = dataSet[.instanceNumber]?.integerStringValue?.value
        let contentLabel = dataSet.string(for: .contentLabel)
        let contentDescription = dataSet.string(for: .contentDescription)
        let contentCreatorName = dataSet.personName(for: .contentCreatorName)
        let contentDate = dataSet.date(for: .contentDate)
        let contentTime = dataSet.time(for: .contentTime)
        
        // Parse Derivation Information
        let derivationDescription = dataSet.string(for: .derivationDescription)
        let derivationCodeSequence = parseCodedEntries(from: dataSet, tag: .derivationCodeSequence)
        
        // Parse Real World Value Mappings (required for Parametric Maps)
        let realWorldValueMappings = parseRealWorldValueMappings(from: dataSet)
        
        // Parse Frame of Reference and Dimension Organization
        let frameOfReferenceUID = dataSet.string(for: .frameOfReferenceUID)
        let dimensionOrganizationUID = dataSet.string(for: .dimensionOrganizationUID)
        
        // Parse Referenced Series
        let referencedSeries = parseReferencedSeries(from: dataSet)
        
        // Parse Pixel Data Properties (required for multi-frame images)
        guard let numberOfFrames = dataSet[.numberOfFrames]?.integerStringValue?.value else {
            throw DICOMError.parsingFailed("Missing Number of Frames")
        }
        
        guard let rows = dataSet.uint16(for: .rows) else {
            throw DICOMError.parsingFailed("Missing Rows")
        }
        
        guard let columns = dataSet.uint16(for: .columns) else {
            throw DICOMError.parsingFailed("Missing Columns")
        }
        
        guard let bitsAllocated = dataSet.uint16(for: .bitsAllocated) else {
            throw DICOMError.parsingFailed("Missing Bits Allocated")
        }
        
        guard let bitsStored = dataSet.uint16(for: .bitsStored) else {
            throw DICOMError.parsingFailed("Missing Bits Stored")
        }
        
        guard let highBit = dataSet.uint16(for: .highBit) else {
            throw DICOMError.parsingFailed("Missing High Bit")
        }
        
        let samplesPerPixel = dataSet.uint16(for: .samplesPerPixel) ?? 1
        let photometricInterpretation = dataSet.string(for: .photometricInterpretation) ?? "MONOCHROME2"
        let pixelRepresentation = dataSet.uint16(for: .pixelRepresentation) ?? 0
        
        // Parse Functional Groups
        let sharedFunctionalGroups = parseSharedFunctionalGroups(from: dataSet)
        let perFrameFunctionalGroups = parsePerFrameFunctionalGroups(from: dataSet)
        
        return ParametricMap(
            sopInstanceUID: sopInstanceUID,
            sopClassUID: sopClassUID,
            seriesInstanceUID: seriesInstanceUID,
            studyInstanceUID: studyInstanceUID,
            instanceNumber: instanceNumber,
            contentLabel: contentLabel,
            contentDescription: contentDescription,
            contentCreatorName: contentCreatorName,
            contentDate: contentDate,
            contentTime: contentTime,
            derivationDescription: derivationDescription,
            derivationCodeSequence: derivationCodeSequence,
            realWorldValueMappings: realWorldValueMappings,
            frameOfReferenceUID: frameOfReferenceUID,
            dimensionOrganizationUID: dimensionOrganizationUID,
            referencedSeries: referencedSeries,
            numberOfFrames: numberOfFrames,
            rows: Int(rows),
            columns: Int(columns),
            bitsAllocated: Int(bitsAllocated),
            bitsStored: Int(bitsStored),
            highBit: Int(highBit),
            samplesPerPixel: Int(samplesPerPixel),
            photometricInterpretation: photometricInterpretation,
            pixelRepresentation: Int(pixelRepresentation),
            sharedFunctionalGroups: sharedFunctionalGroups,
            perFrameFunctionalGroups: perFrameFunctionalGroups
        )
    }
    
    // MARK: - Private Parsing Methods
    
    /// Parse Real World Value Mapping Sequence
    private static func parseRealWorldValueMappings(from dataSet: DataSet) -> [RealWorldValueMapping] {
        // Check for mappings in shared functional groups
        if let sharedGroups = dataSet.sequence(for: .sharedFunctionalGroupsSequence)?.first,
           let mappingSequence = sharedGroups.sequence(for: .realWorldValueMappingSequence) {
            return mappingSequence.compactMap { parseRealWorldValueMapping(from: $0) }
        }
        
        // Check for mappings at the dataset level
        if let mappingSequence = dataSet.sequence(for: .realWorldValueMappingSequence) {
            return mappingSequence.compactMap { parseRealWorldValueMapping(from: $0) }
        }
        
        return []
    }
    
    /// Parse a single Real World Value Mapping item
    private static func parseRealWorldValueMapping(from item: DataSet) -> RealWorldValueMapping? {
        // Parse label and explanation
        let label = item.string(for: .lutLabel)
        let explanation = item.string(for: .lutExplanation)
        
        // Parse measurement units (required)
        guard let measurementUnits = parseMeasurementUnits(from: item) else {
            return nil
        }
        
        // Parse quantity definition (optional)
        let quantityDefinition = parseQuantityDefinition(from: item)
        
        // Determine mapping method (linear or LUT)
        let mapping: MappingMethod
        
        // Check for linear transformation (slope/intercept)
        if let slope = item[.realWorldValueSlope]?.doubleFloatValue,
           let intercept = item[.realWorldValueIntercept]?.doubleFloatValue {
            mapping = .linear(slope: slope, intercept: intercept)
        }
        // Check for explicit LUT data
        else if let lutData = item[.realWorldValueLUTData]?.doubleFloatArray,
                !lutData.isEmpty {
            let firstValue = item[.doubleFloatRealWorldValueFirstValueMapped]?.doubleFloatValue ?? 0.0
            let lastValue = item[.doubleFloatRealWorldValueLastValueMapped]?.doubleFloatValue ?? Double(lutData.count - 1)
            mapping = .lut(firstValueMapped: firstValue, lastValueMapped: lastValue, lutData: lutData)
        }
        else {
            // No valid mapping found
            return nil
        }
        
        return RealWorldValueMapping(
            label: label,
            explanation: explanation,
            measurementUnits: measurementUnits,
            quantityDefinition: quantityDefinition,
            mapping: mapping
        )
    }
    
    /// Parse Measurement Units Code Sequence
    private static func parseMeasurementUnits(from dataSet: DataSet) -> MeasurementUnits? {
        guard let sequence = dataSet.sequence(for: .measurementUnitsCodeSequence)?.first else {
            return nil
        }
        
        guard let codeValue = sequence.string(for: .codeValue),
              let codeMeaning = sequence.string(for: .codeMeaning) else {
            return nil
        }
        
        let codingSchemeDesignator = sequence.string(for: .codingSchemeDesignator) ?? "UCUM"
        
        return MeasurementUnits(
            codeValue: codeValue,
            codingSchemeDesignator: codingSchemeDesignator,
            codeMeaning: codeMeaning
        )
    }
    
    /// Parse Quantity Definition Sequence
    private static func parseQuantityDefinition(from dataSet: DataSet) -> QuantityDefinition? {
        guard let sequence = dataSet.sequence(for: .quantityDefinitionSequence)?.first else {
            return nil
        }
        
        guard let codeValue = sequence.string(for: .codeValue),
              let codingSchemeDesignator = sequence.string(for: .codingSchemeDesignator),
              let codeMeaning = sequence.string(for: .codeMeaning) else {
            return nil
        }
        
        return QuantityDefinition(
            codeValue: codeValue,
            codingSchemeDesignator: codingSchemeDesignator,
            codeMeaning: codeMeaning
        )
    }
    
    /// Parse coded entries from a sequence
    private static func parseCodedEntries(from dataSet: DataSet, tag: Tag) -> [CodedEntry] {
        guard let sequence = dataSet.sequence(for: tag) else {
            return []
        }
        
        return sequence.compactMap { item in
            guard let codeValue = item.string(for: .codeValue),
                  let codingSchemeDesignator = item.string(for: .codingSchemeDesignator),
                  let codeMeaning = item.string(for: .codeMeaning) else {
                return nil
            }
            
            return CodedEntry(
                codeValue: codeValue,
                codingSchemeDesignator: codingSchemeDesignator,
                codeMeaning: codeMeaning
            )
        }
    }
    
    /// Parse Referenced Series Sequence
    private static func parseReferencedSeries(from dataSet: DataSet) -> [ParametricMapReferencedSeries] {
        guard let sequence = dataSet.sequence(for: .referencedSeriesSequence) else {
            return []
        }
        
        return sequence.compactMap { seriesItem in
            guard let seriesInstanceUID = seriesItem.string(for: .seriesInstanceUID) else {
                return nil
            }
            
            let referencedInstances = parseReferencedInstances(from: seriesItem)
            
            return ParametricMapReferencedSeries(
                seriesInstanceUID: seriesInstanceUID,
                referencedInstances: referencedInstances
            )
        }
    }
    
    /// Parse Referenced Instance Sequence
    private static func parseReferencedInstances(from dataSet: DataSet) -> [ReferencedInstance] {
        guard let sequence = dataSet.sequence(for: .referencedInstanceSequence) else {
            return []
        }
        
        return sequence.compactMap { instanceItem in
            guard let sopClassUID = instanceItem.string(for: .referencedSOPClassUID),
                  let sopInstanceUID = instanceItem.string(for: .referencedSOPInstanceUID) else {
                return nil
            }
            
            let frameNumbers = instanceItem[.referencedFrameNumber]?.integerStringArray?.map(\.value) ?? []
            
            return ReferencedInstance(
                referencedSOPClassUID: sopClassUID,
                referencedSOPInstanceUID: sopInstanceUID,
                referencedFrameNumbers: frameNumbers
            )
        }
    }
    
    /// Parse Shared Functional Groups Sequence
    private static func parseSharedFunctionalGroups(from dataSet: DataSet) -> FunctionalGroup? {
        guard let sequence = dataSet.sequence(for: .sharedFunctionalGroupsSequence),
              let firstItem = sequence.first else {
            return nil
        }
        
        return FunctionalGroup(dataSet: firstItem)
    }
    
    /// Parse Per-Frame Functional Groups Sequence
    private static func parsePerFrameFunctionalGroups(from dataSet: DataSet) -> [FunctionalGroup] {
        guard let sequence = dataSet.sequence(for: .perFrameFunctionalGroupsSequence) else {
            return []
        }
        
        return sequence.map { FunctionalGroup(dataSet: $0) }
    }
}

// MARK: - DataSet Extensions

extension DataSet {
    
    /// Get double-precision floating point value
    fileprivate var doubleFloatValue: Double? {
        // Try FD (Floating Point Double) first
        if let fd = self[.realWorldValueIntercept]?.value as? Data,
           fd.count >= 8 {
            return fd.withUnsafeBytes { $0.loadUnaligned(as: Double.self) }
        }
        
        // Try DS (Decimal String) as fallback
        if let ds = self[.realWorldValueIntercept]?.decimalStringValue?.value {
            return ds
        }
        
        return nil
    }
    
    /// Get double-precision floating point array
    fileprivate var doubleFloatArray: [Double]? {
        // Try FD (Floating Point Double) VR
        if let fd = self[.realWorldValueLUTData]?.value as? Data {
            let count = fd.count / 8
            guard count > 0 else { return nil }
            
            return fd.withUnsafeBytes { buffer in
                let pointer = buffer.bindMemory(to: Double.self)
                return Array(pointer.prefix(count))
            }
        }
        
        return nil
    }
}
