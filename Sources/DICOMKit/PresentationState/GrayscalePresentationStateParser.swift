//
// GrayscalePresentationStateParser.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-04.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Parser for Grayscale Softcopy Presentation State objects
///
/// Converts a DICOM DataSet into a `GrayscalePresentationState` structure.
///
/// Reference: PS3.3 Part 3 Section A.33 - Grayscale Softcopy Presentation State IOD
///
/// Example:
/// ```swift
/// let parser = GrayscalePresentationStateParser()
/// let presentationState = try parser.parse(dataSet: dataSet)
/// ```
public struct GrayscalePresentationStateParser: Sendable {
    
    /// Parser errors
    public enum ParseError: Error, Sendable {
        /// Missing required attribute
        case missingRequiredAttribute(tag: String, description: String)
        
        /// Invalid SOP Class UID (not a GSPS)
        case invalidSOPClassUID(String)
        
        /// Invalid SOP Instance UID
        case invalidSOPInstanceUID
        
        /// Invalid LUT descriptor format
        case invalidLUTDescriptor(String)
        
        /// Invalid graphic data
        case invalidGraphicData(String)
        
        /// Invalid shutter data
        case invalidShutterData(String)
    }
    
    /// Creates a new GSPS parser
    public init() {}
    
    // MARK: - Public Parsing API
    
    /// Parses a DICOM DataSet into a GrayscalePresentationState
    ///
    /// - Parameter dataSet: The DICOM data set to parse
    /// - Returns: A parsed grayscale presentation state
    /// - Throws: ParseError if the data set is not a valid GSPS
    public func parse(dataSet: DataSet) throws -> GrayscalePresentationState {
        // Parse SOP Class UID and verify it's a GSPS
        guard let sopClassUID = dataSet.string(for: .sopClassUID) else {
            throw ParseError.missingRequiredAttribute(
                tag: "0008,0016",
                description: "SOP Class UID"
            )
        }
        
        // Verify this is a Grayscale Softcopy Presentation State
        guard sopClassUID == .grayscaleSoftcopyPresentationStateStorage else {
            throw ParseError.invalidSOPClassUID(sopClassUID)
        }
        
        // Parse SOP Instance UID
        guard let sopInstanceUID = dataSet.string(for: .sopInstanceUID) else {
            throw ParseError.invalidSOPInstanceUID
        }
        
        // Parse Presentation State Identification Module
        let instanceNumber = dataSet.integer(for: .presentationInstanceNumber)
        let presentationLabel = dataSet.string(for: .presentationLabel)
        let presentationDescription = dataSet.string(for: .presentationDescription)
        let presentationCreationDate = dataSet.date(for: .presentationCreationDate)
        let presentationCreationTime = dataSet.time(for: .presentationCreationTime)
        let presentationCreatorsName = dataSet.personName(for: .presentationCreatorsName)
        
        // Parse Presentation State Relationship Module
        let referencedSeries = try parseReferencedSeries(from: dataSet)
        
        // Parse Display Transformation Modules
        let modalityLUT = try parseModalityLUT(from: dataSet)
        let voiLUT = try parseVOILUT(from: dataSet)
        let presentationLUT = try parsePresentationLUT(from: dataSet)
        
        // Parse Spatial Transformation Module
        let spatialTransformation = parseSpatialTransformation(from: dataSet)
        
        // Parse Displayed Area Module
        let displayedArea = parseDisplayedArea(from: dataSet)
        
        // Parse Graphic Layer Module
        let graphicLayers = parseGraphicLayers(from: dataSet)
        
        // Parse Graphic Annotation Module
        let graphicAnnotations = try parseGraphicAnnotations(from: dataSet)
        
        // Parse Display Shutter Module
        let shutters = try parseDisplayShutters(from: dataSet)
        
        return GrayscalePresentationState(
            sopInstanceUID: sopInstanceUID,
            sopClassUID: sopClassUID,
            instanceNumber: instanceNumber,
            presentationLabel: presentationLabel,
            presentationDescription: presentationDescription,
            presentationCreationDate: presentationCreationDate,
            presentationCreationTime: presentationCreationTime,
            presentationCreatorsName: presentationCreatorsName,
            referencedSeries: referencedSeries,
            modalityLUT: modalityLUT,
            voiLUT: voiLUT,
            presentationLUT: presentationLUT,
            spatialTransformation: spatialTransformation,
            displayedArea: displayedArea,
            graphicLayers: graphicLayers,
            graphicAnnotations: graphicAnnotations,
            shutters: shutters
        )
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseReferencedSeries(from dataSet: DataSet) throws -> [ReferencedSeries] {
        guard let seriesSequence = dataSet.sequence(for: .referencedSeriesSequence) else {
            throw ParseError.missingRequiredAttribute(
                tag: "0008,1115",
                description: "Referenced Series Sequence"
            )
        }
        
        return try seriesSequence.items.compactMap { item in
            guard let seriesInstanceUID = item.dataSet.string(for: .seriesInstanceUID) else {
                return nil
            }
            
            let referencedImages: [ReferencedImage]
            if let imageSequence = item.dataSet.sequence(for: .referencedImageSequence) {
                referencedImages = imageSequence.items.compactMap { imageItem in
                    guard let sopClassUID = imageItem.dataSet.string(for: .referencedSOPClassUID),
                          let sopInstanceUID = imageItem.dataSet.string(for: .referencedSOPInstanceUID) else {
                        return nil
                    }
                    
                    let frameNumbers = imageItem.dataSet.integers(for: .referencedFrameNumber)
                    
                    return ReferencedImage(
                        sopClassUID: sopClassUID,
                        sopInstanceUID: sopInstanceUID,
                        referencedFrameNumbers: frameNumbers
                    )
                }
            } else {
                referencedImages = []
            }
            
            return ReferencedSeries(
                seriesInstanceUID: seriesInstanceUID,
                referencedImages: referencedImages
            )
        }
    }
    
    private func parseModalityLUT(from dataSet: DataSet) throws -> ModalityLUT? {
        // Check for LUT Sequence first
        if let lutSequence = dataSet.sequence(for: .modalityLUTSequence),
           let firstItem = lutSequence.items.first {
            let lutData = try parseLUTData(from: firstItem.dataSet)
            return .lut(lutData)
        }
        
        // Check for Rescale Slope/Intercept
        if let slope = dataSet.decimal(for: .rescaleSlope),
           let intercept = dataSet.decimal(for: .rescaleIntercept) {
            let type = dataSet.string(for: .rescaleType)
            return .rescale(slope: slope, intercept: intercept, type: type)
        }
        
        return nil
    }
    
    private func parseVOILUT(from dataSet: DataSet) throws -> VOILUT? {
        // Check for LUT Sequence first
        if let lutSequence = dataSet.sequence(for: .voiLUTSequence),
           let firstItem = lutSequence.items.first {
            let lutData = try parseLUTData(from: firstItem.dataSet)
            return .lut(lutData)
        }
        
        // Check for Window Center/Width
        if let centers = dataSet.decimals(for: .windowCenter),
           let widths = dataSet.decimals(for: .windowWidth),
           let center = centers.first,
           let width = widths.first {
            let explanation = dataSet.string(for: .windowCenterWidthExplanation)
            let functionString = dataSet.string(for: .voiLUTFunction)
            let function = VOILUTFunction.parse(functionString)
            
            return .window(center: center, width: width, explanation: explanation, function: function)
        }
        
        return nil
    }
    
    private func parsePresentationLUT(from dataSet: DataSet) throws -> PresentationLUT? {
        // Check for Presentation LUT Sequence
        if let lutSequence = dataSet.sequence(for: .presentationLUTSequence),
           let firstItem = lutSequence.items.first {
            let lutData = try parseLUTData(from: firstItem.dataSet)
            return .lut(lutData)
        }
        
        // Check for Presentation LUT Shape
        if let shape = dataSet.string(for: .presentationLUTShape) {
            switch shape {
            case "IDENTITY":
                return .identity
            case "INVERSE":
                return .inverse
            default:
                return .identity
            }
        }
        
        return nil
    }
    
    private func parseLUTData(from dataSet: DataSet) throws -> LUTData {
        guard let descriptorInts = dataSet.integers(for: .lutDescriptor) else {
            throw ParseError.invalidLUTDescriptor("Missing LUT Descriptor")
        }
        
        guard let data = dataSet.integers(for: .lutData) else {
            throw ParseError.invalidLUTDescriptor("Missing LUT Data")
        }
        
        let explanation = dataSet.string(for: .lutExplanation)
        
        guard let lutData = LUTData.parse(descriptor: descriptorInts, data: data, explanation: explanation) else {
            throw ParseError.invalidLUTDescriptor("Invalid LUT Descriptor format")
        }
        
        return lutData
    }
    
    private func parseSpatialTransformation(from dataSet: DataSet) -> SpatialTransformation? {
        let rotation = dataSet.integer(for: .imageRotation) ?? 0
        let flipString = dataSet.string(for: .imageHorizontalFlip)
        let horizontalFlip = flipString == "Y"
        
        if rotation != 0 || horizontalFlip {
            return SpatialTransformation(rotation: rotation, horizontalFlip: horizontalFlip)
        }
        
        return nil
    }
    
    private func parseDisplayedArea(from dataSet: DataSet) -> DisplayedArea? {
        guard let displayedAreaSequence = dataSet.sequence(for: .displayedAreaSelectionSequence),
              let firstItem = displayedAreaSequence.items.first else {
            return nil
        }
        
        let item = firstItem.dataSet
        
        guard let topLeftValues = item.integers(for: .displayedAreaTopLeftHandCorner),
              topLeftValues.count == 2,
              let bottomRightValues = item.integers(for: .displayedAreaBottomRightHandCorner),
              bottomRightValues.count == 2 else {
            return nil
        }
        
        let topLeft = (column: topLeftValues[0], row: topLeftValues[1])
        let bottomRight = (column: bottomRightValues[0], row: bottomRightValues[1])
        
        let sizeModeString = item.string(for: .presentationSizeMode) ?? "SCALE TO FIT"
        let sizeMode = PresentationSizeMode(rawValue: sizeModeString) ?? .scaleToFit
        
        return DisplayedArea(topLeft: topLeft, bottomRight: bottomRight, sizeMode: sizeMode)
    }
    
    private func parseGraphicLayers(from dataSet: DataSet) -> [GraphicLayer] {
        guard let layerSequence = dataSet.sequence(for: .graphicLayerSequence) else {
            return []
        }
        
        return layerSequence.items.compactMap { item in
            guard let name = item.dataSet.string(for: .graphicLayer),
                  let order = item.dataSet.integer(for: .graphicLayerOrder) else {
                return nil
            }
            
            let description = item.dataSet.string(for: .graphicLayerDescription)
            let grayscaleValue = item.dataSet.integer(for: .graphicLayerRecommendedDisplayGrayscaleValue)
            
            var rgbValue: (red: Int, green: Int, blue: Int)? = nil
            if let rgbValues = item.dataSet.integers(for: .graphicLayerRecommendedDisplayRGBValue),
               rgbValues.count == 3 {
                rgbValue = (red: rgbValues[0], green: rgbValues[1], blue: rgbValues[2])
            }
            
            return GraphicLayer(
                name: name,
                order: order,
                description: description,
                recommendedGrayscaleValue: grayscaleValue,
                recommendedRGBValue: rgbValue
            )
        }
    }
    
    private func parseGraphicAnnotations(from dataSet: DataSet) throws -> [GraphicAnnotation] {
        guard let annotationSequence = dataSet.sequence(for: .graphicAnnotationSequence) else {
            return []
        }
        
        return try annotationSequence.items.compactMap { item in
            guard let layer = item.dataSet.string(for: .graphicLayer) else {
                return nil
            }
            
            // Parse referenced images
            var referencedImages: [ReferencedImage] = []
            if let refImageSeq = item.dataSet.sequence(for: .referencedImageSequence) {
                referencedImages = refImageSeq.items.compactMap { refItem in
                    guard let sopClassUID = refItem.dataSet.string(for: .referencedSOPClassUID),
                          let sopInstanceUID = refItem.dataSet.string(for: .referencedSOPInstanceUID) else {
                        return nil
                    }
                    
                    let frameNumbers = refItem.dataSet.integers(for: .referencedFrameNumber)
                    
                    return ReferencedImage(
                        sopClassUID: sopClassUID,
                        sopInstanceUID: sopInstanceUID,
                        referencedFrameNumbers: frameNumbers
                    )
                }
            }
            
            // Parse graphic objects
            var graphicObjects: [GraphicObject] = []
            if let graphicSeq = item.dataSet.sequence(for: .graphicObjectSequence) {
                graphicObjects = try graphicSeq.items.compactMap { graphicItem in
                    try parseGraphicObject(from: graphicItem.dataSet)
                }
            }
            
            // Parse text objects
            var textObjects: [TextObject] = []
            if let textSeq = item.dataSet.sequence(for: .textObjectSequence) {
                textObjects = textSeq.items.compactMap { textItem in
                    parseTextObject(from: textItem.dataSet)
                }
            }
            
            return GraphicAnnotation(
                layer: layer,
                referencedImages: referencedImages,
                graphicObjects: graphicObjects,
                textObjects: textObjects
            )
        }
    }
    
    private func parseGraphicObject(from dataSet: DataSet) throws -> GraphicObject? {
        guard let typeString = dataSet.string(for: .graphicType),
              let type = PresentationGraphicType(rawValue: typeString),
              let data = dataSet.decimals(for: .graphicData) else {
            return nil
        }
        
        let filledString = dataSet.string(for: .graphicFilled)
        let filled = filledString == "Y"
        
        let unitsString = dataSet.string(for: .boundingBoxAnnotationUnits) ?? "PIXEL"
        let units = AnnotationUnits(rawValue: unitsString) ?? .pixel
        
        return GraphicObject(type: type, data: data, filled: filled, units: units)
    }
    
    private func parseTextObject(from dataSet: DataSet) -> TextObject? {
        guard let text = dataSet.string(for: .unformattedTextValue),
              let topLeftValues = dataSet.decimals(for: .boundingBoxTopLeftHandCorner),
              topLeftValues.count == 2,
              let bottomRightValues = dataSet.decimals(for: .boundingBoxBottomRightHandCorner),
              bottomRightValues.count == 2 else {
            return nil
        }
        
        let topLeft = (column: topLeftValues[0], row: topLeftValues[1])
        let bottomRight = (column: bottomRightValues[0], row: bottomRightValues[1])
        
        var anchorPoint: (column: Double, row: Double)? = nil
        if let anchorValues = dataSet.decimals(for: .anchorPoint),
           anchorValues.count == 2 {
            anchorPoint = (column: anchorValues[0], row: anchorValues[1])
        }
        
        let anchorVisibleString = dataSet.string(for: .anchorPointVisibility)
        let anchorVisible = anchorVisibleString == "Y"
        
        let boundingBoxUnitsString = dataSet.string(for: .boundingBoxAnnotationUnits) ?? "PIXEL"
        let boundingBoxUnits = AnnotationUnits(rawValue: boundingBoxUnitsString) ?? .pixel
        
        let anchorPointUnitsString = dataSet.string(for: .anchorPointAnnotationUnits) ?? "PIXEL"
        let anchorPointUnits = AnnotationUnits(rawValue: anchorPointUnitsString) ?? .pixel
        
        return TextObject(
            text: text,
            boundingBoxTopLeft: topLeft,
            boundingBoxBottomRight: bottomRight,
            anchorPoint: anchorPoint,
            anchorPointVisible: anchorVisible,
            boundingBoxUnits: boundingBoxUnits,
            anchorPointUnits: anchorPointUnits
        )
    }
    
    private func parseDisplayShutters(from dataSet: DataSet) throws -> [DisplayShutter] {
        guard let shapesString = dataSet.string(for: .shutterShape) else {
            return []
        }
        
        let shapes = shapesString.split(separator: "\\").map { String($0) }
        var shutters: [DisplayShutter] = []
        
        let presentationValue = dataSet.integer(for: .shutterPresentationValue)
        
        for shape in shapes {
            switch shape {
            case "RECTANGULAR":
                if let left = dataSet.integer(for: .shutterLeftVerticalEdge),
                   let right = dataSet.integer(for: .shutterRightVerticalEdge),
                   let top = dataSet.integer(for: .shutterUpperHorizontalEdge),
                   let bottom = dataSet.integer(for: .shutterLowerHorizontalEdge) {
                    shutters.append(.rectangular(
                        left: left,
                        right: right,
                        top: top,
                        bottom: bottom,
                        presentationValue: presentationValue
                    ))
                }
                
            case "CIRCULAR":
                if let centerValues = dataSet.integers(for: .centerOfCircularShutter),
                   centerValues.count == 2,
                   let radius = dataSet.integer(for: .radiusOfCircularShutter) {
                    shutters.append(.circular(
                        centerColumn: centerValues[0],
                        centerRow: centerValues[1],
                        radius: radius,
                        presentationValue: presentationValue
                    ))
                }
                
            case "POLYGONAL":
                if let vertexData = dataSet.integers(for: .verticesOfPolygonalShutter),
                   vertexData.count >= 6, vertexData.count % 2 == 0 {
                    var vertices: [(column: Int, row: Int)] = []
                    for i in stride(from: 0, to: vertexData.count, by: 2) {
                        vertices.append((column: vertexData[i], row: vertexData[i+1]))
                    }
                    shutters.append(.polygonal(vertices: vertices, presentationValue: presentationValue))
                }
                
            case "BITMAP":
                if let overlayGroup = dataSet.integer(for: .shutterOverlayGroup) {
                    shutters.append(.bitmap(overlayGroup: overlayGroup, presentationValue: presentationValue))
                }
                
            default:
                break
            }
        }
        
        return shutters
    }
}
