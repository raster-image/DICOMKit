//
// Tag+PresentationState.swift
// DICOMCore
//
// Created by DICOMKit on 2026-02-04.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation

/// DICOM tags for Grayscale Softcopy Presentation State
///
/// Reference: PS3.3 Part 3 Section A.33 - Grayscale Softcopy Presentation State IOD
extension Tag {
    // MARK: - Presentation State Identification Module (C.11.10)
    
    /// Instance Number (0020,0013)
    public static let presentationInstanceNumber = Tag(0x0020, 0x0013)
    
    /// Presentation Label (0070,0080)
    public static let presentationLabel = Tag(0x0070, 0x0080)
    
    /// Presentation Description (0070,0081)
    public static let presentationDescription = Tag(0x0070, 0x0081)
    
    /// Presentation Creation Date (0070,0082)
    public static let presentationCreationDate = Tag(0x0070, 0x0082)
    
    /// Presentation Creation Time (0070,0083)
    public static let presentationCreationTime = Tag(0x0070, 0x0083)
    
    /// Presentation Creator's Name (0070,0084)
    public static let presentationCreatorsName = Tag(0x0070, 0x0084)
    
    // MARK: - Presentation State Relationship Module (C.11.11)
    
    /// Referenced Series Sequence (0008,1115)
    public static let referencedSeriesSequence = Tag(0x0008, 0x1115)
    
    /// Referenced Image Sequence (0008,1140)
    public static let referencedImageSequence = Tag(0x0008, 0x1140)
    
    // MARK: - Graphic Annotation Module (C.10.5)
    
    /// Graphic Annotation Sequence (0070,0001)
    public static let graphicAnnotationSequence = Tag(0x0070, 0x0001)
    
    /// Graphic Layer (0070,0002)
    public static let graphicLayer = Tag(0x0070, 0x0002)
    
    /// Text Object Sequence (0070,0008)
    public static let textObjectSequence = Tag(0x0070, 0x0008)
    
    /// Graphic Object Sequence (0070,0009)
    public static let graphicObjectSequence = Tag(0x0070, 0x0009)
    
    /// Bounding Box Annotation Units (0070,0003)
    public static let boundingBoxAnnotationUnits = Tag(0x0070, 0x0003)
    
    /// Anchor Point Annotation Units (0070,0004)
    public static let anchorPointAnnotationUnits = Tag(0x0070, 0x0004)
    
    /// Unformatted Text Value (0070,0006)
    public static let unformattedTextValue = Tag(0x0070, 0x0006)
    
    /// Bounding Box Top Left Hand Corner (0070,0010)
    public static let boundingBoxTopLeftHandCorner = Tag(0x0070, 0x0010)
    
    /// Bounding Box Bottom Right Hand Corner (0070,0011)
    public static let boundingBoxBottomRightHandCorner = Tag(0x0070, 0x0011)
    
    /// Anchor Point (0070,0014)
    public static let anchorPoint = Tag(0x0070, 0x0014)
    
    /// Anchor Point Visibility (0070,0015)
    public static let anchorPointVisibility = Tag(0x0070, 0x0015)
    
    /// Graphic Data (0070,0022)
    public static let graphicData = Tag(0x0070, 0x0022)
    
    /// Graphic Type (0070,0023)
    public static let graphicType = Tag(0x0070, 0x0023)
    
    /// Graphic Filled (0070,0024)
    public static let graphicFilled = Tag(0x0070, 0x0024)
    
    // MARK: - Graphic Layer Module (C.10.7)
    
    /// Graphic Layer Sequence (0070,0060)
    public static let graphicLayerSequence = Tag(0x0070, 0x0060)
    
    /// Graphic Layer Order (0070,0062)
    public static let graphicLayerOrder = Tag(0x0070, 0x0062)
    
    /// Graphic Layer Recommended Display Grayscale Value (0070,0066)
    public static let graphicLayerRecommendedDisplayGrayscaleValue = Tag(0x0070, 0x0066)
    
    /// Graphic Layer Recommended Display RGB Value (0070,0067)
    public static let graphicLayerRecommendedDisplayRGBValue = Tag(0x0070, 0x0067)
    
    /// Graphic Layer Description (0070,0068)
    public static let graphicLayerDescription = Tag(0x0070, 0x0068)
    
    // MARK: - Spatial Transformation Module (C.10.6)
    
    /// Image Rotation (0070,0042)
    public static let imageRotation = Tag(0x0070, 0x0042)
    
    /// Image Horizontal Flip (0070,0041)
    public static let imageHorizontalFlip = Tag(0x0070, 0x0041)
    
    // MARK: - Display Shutter Module (C.7.6.11)
    
    /// Shutter Shape (0018,1600)
    public static let shutterShape = Tag(0x0018, 0x1600)
    
    /// Shutter Left Vertical Edge (0018,1602)
    public static let shutterLeftVerticalEdge = Tag(0x0018, 0x1602)
    
    /// Shutter Right Vertical Edge (0018,1604)
    public static let shutterRightVerticalEdge = Tag(0x0018, 0x1604)
    
    /// Shutter Upper Horizontal Edge (0018,1606)
    public static let shutterUpperHorizontalEdge = Tag(0x0018, 0x1606)
    
    /// Shutter Lower Horizontal Edge (0018,1608)
    public static let shutterLowerHorizontalEdge = Tag(0x0018, 0x1608)
    
    /// Center of Circular Shutter (0018,1610)
    public static let centerOfCircularShutter = Tag(0x0018, 0x1610)
    
    /// Radius of Circular Shutter (0018,1612)
    public static let radiusOfCircularShutter = Tag(0x0018, 0x1612)
    
    /// Vertices of the Polygonal Shutter (0018,1620)
    public static let verticesOfPolygonalShutter = Tag(0x0018, 0x1620)
    
    /// Shutter Presentation Value (0018,1622)
    public static let shutterPresentationValue = Tag(0x0018, 0x1622)
    
    /// Shutter Overlay Group (0018,1623)
    public static let shutterOverlayGroup = Tag(0x0018, 0x1623)
    
    // MARK: - Displayed Area Module (C.10.4)
    
    /// Displayed Area Selection Sequence (0070,005A)
    public static let displayedAreaSelectionSequence = Tag(0x0070, 0x005A)
    
    /// Displayed Area Top Left Hand Corner (0070,0052)
    public static let displayedAreaTopLeftHandCorner = Tag(0x0070, 0x0052)
    
    /// Displayed Area Bottom Right Hand Corner (0070,0053)
    public static let displayedAreaBottomRightHandCorner = Tag(0x0070, 0x0053)
    
    /// Presentation Size Mode (0070,0100)
    public static let presentationSizeMode = Tag(0x0070, 0x0100)
    
    /// Presentation Pixel Spacing (0070,0101)
    public static let presentationPixelSpacing = Tag(0x0070, 0x0101)
    
    /// Presentation Pixel Aspect Ratio (0070,0102)
    public static let presentationPixelAspectRatio = Tag(0x0070, 0x0102)
    
    /// Presentation Pixel Magnification Ratio (0070,0103)
    public static let presentationPixelMagnificationRatio = Tag(0x0070, 0x0103)
    
    // MARK: - Modality LUT Module (C.11.1)
    
    /// Modality LUT Sequence (0028,3000)
    public static let modalityLUTSequence = Tag(0x0028, 0x3000)
    
    /// Rescale Intercept (0028,1052)
    public static let rescaleIntercept = Tag(0x0028, 0x1052)
    
    /// Rescale Slope (0028,1053)
    public static let rescaleSlope = Tag(0x0028, 0x1053)
    
    /// Rescale Type (0028,1054)
    public static let rescaleType = Tag(0x0028, 0x1054)
    
    // MARK: - VOI LUT Module (C.11.2)
    
    /// VOI LUT Sequence (0028,3010)
    public static let voiLUTSequence = Tag(0x0028, 0x3010)
    
    /// Window Center (0028,1050)
    public static let windowCenter = Tag(0x0028, 0x1050)
    
    /// Window Width (0028,1051)
    public static let windowWidth = Tag(0x0028, 0x1051)
    
    /// Window Center & Width Explanation (0028,1055)
    public static let windowCenterWidthExplanation = Tag(0x0028, 0x1055)
    
    /// VOI LUT Function (0028,1056)
    public static let voiLUTFunction = Tag(0x0028, 0x1056)
    
    // MARK: - Presentation LUT Module (C.11.6)
    
    /// Presentation LUT Sequence (2050,0010)
    public static let presentationLUTSequence = Tag(0x2050, 0x0010)
    
    /// Presentation LUT Shape (2050,0020)
    public static let presentationLUTShape = Tag(0x2050, 0x0020)
    
    // MARK: - LUT Common Attributes
    
    /// LUT Descriptor (0028,3002 for Modality LUT, 0028,3010 for VOI LUT)
    public static let lutDescriptor = Tag(0x0028, 0x3002)
    
    /// LUT Data (0028,3006)
    public static let lutData = Tag(0x0028, 0x3006)
    
    /// LUT Explanation (0028,3003)
    public static let lutExplanation = Tag(0x0028, 0x3003)
}
