/* 
	This macro adds multiple operating parameters extracted from the header of Olympus DSX images.
	Additional parameters are calculated using this data.
	It also automatically embeds the distance calibration in microns if there is no calibration present (or it is in inches).
	v220301: 1st working version
	v220304: Added option to put annotation bar under image SEM-style.
	v220307: Saved preferences added. v220307-f1 restored saveSettings f3: updated pad function f4: updated functions 230111
	v230112: Now works with montages generated and resized by DSX software. f1: changed exifDSXs function to assume the metaData has been imported already by ImageJ
	v230120b-v230123: Optimized for much faster imageJ info import. Better hanlding of DSX image that has been cropped after opening. f1: updated stripKnownExtensionFromString function
	v230512: Switched to using exifReader plugin to get a more complete exif import.
	v230513: Smarter about monochrome images. Adds transfer of metaData option.
	v230516: Fixed old variable names left in imported scales lines. f1: updated DSX tag functions.f2 update stripKnowExtension. F3: Updated indexOfArray functions. F4: getColorArrayFromColorName_v230908.  F10 : Replaced function: pad.
 */
macro "Add Multiple Lines of Metadata to DSX Image" {
	macroL = "DSX_Annotator_v230516-f10.ijm";
	if (nImages==0) exit("sorry, this macro only works on open images");
	imageTitle = getTitle();
	um = getInfo("micrometer.abbreviation");
	if (!endsWith(toLowerCase(imageTitle), '.dsx'))
		showMessageWithCancel("Title does not end with \"DSX\"", "A DSX image is required, do you want to continue?" + imageTitle + " ?");
	// Checks to see if a Ramp legend rather than the image has been selected by accident
	if (matches(imageTitle, ".*Ramp.*")==1) showMessageWithCancel("Title contains \"Ramp\"", "Do you want to label" + imageTitle + " ?");
	/* Settings preferences set up */
	imageCWidth = getWidth(); /* note: this is changed from imageWidth because of DSX info name clash */
	imageCHeight = getHeight(); /* note: this is changed from imageHeight because of DSX info name clash */
	imageDims = imageCHeight + imageCWidth;
	imageDepth = bitDepth();
	id = getImageID();
	userPath = getInfo("user.dir");
	prefsDelimiter = "|";
	prefsNameKey = "ascDSXAnnotatorPrefs.";
	prefsParameters = call("ij.Prefs.get", prefsNameKey+"lastParameters", "None");
	if (prefsParameters!="None") defaultSettings = split(prefsParameters,prefsDelimiter);
	else defaultSettings = newArray("ObservationMethod","ImageType","ImageSizePix","ImageSizeMicrons","ObjectiveLensType","ObjectiveLensMagnification","ZoomMagnification");
	/* End preferences recall */
	settingsDSX = newArray("ObservationMethod","ImageType","ObjectiveLensMagnification","ImageHeight","ImageWidth","ColorDataPerPixelX","ImageDataPerPixelX","ColorDataPerPixelY","ImageDataPerPixelY","ColorDataPerPixelZ","ImageDataPerPixelZ","ObjectiveLensType","ZoomMagnification","DigitalZoomMagnification","OpiticalZoomMagnification","ActualMagnificationFor1xZoom","ImageFlip","ShadingCorrection","ImageAspectRatio","NoiseReduction","NoiseReductionLevel","BlurCorrection","BlurCorrectionValue","ContrastMode","SharpnessMode","FieldCurvatureCorrection","StagePositionX","StagePositionY","ImagingAS","AnalyzerShearingLevel","PBF","CameraName","GammaCorrectionLevel");
	settingsColor = newArray("BlueGainLevel","BlueOffsetLevel","GreenGainLevel","GreenOffsetLevel","RedGainLevel","RedOffsetLevel");
	settingsColorTitles = newArray("Blue Gain Level","Blue Offset Level","Green Gain Level","Green Offset Level","RedGain Level","Red Offset Level");
	settingsDontCare = newArray("FileVersion","MicroscopeControllerVersion"); settingsDontCareTitles = newArray("File Version","Microscope Controller Version");
	settingsDSXBF = newArray("BFLight","BFLightBrightnessLevel"); settingsDSXBFTitles = newArray("BF Light","BF Light Brightness Level");
	settingsDSXDF = newArray("DFLightBlock","DFLightAngle","DFLightMode"); settingsDSXDFTitles = newArray("DF Light Block","DF Light Angle","DF Light Mode");
	settingsDSXAE = newArray("AE","AELock","AEMode","AETargetValue"); settingsDSXAETitles = newArray("Auto Exposure","AE Lock","AE Mode","AE Target Value");
	// settingsRot = newArray("ImageRotation","ImageRotationAngle"); settingsRotTitles = newArray("Image Rotation","Image Rotation Angle");
	// settingsBinning = newArray("Binning","BinningLevel"); settingsBinning = newArray("Binning","Binning Level"); 
	// settingsDSXHDR = newArray("HDRMode", "HDRProcessing"); settingsDSXHDRTitles = newArray("HDR Mode", "HDR Processing"); 
	// notASCFeatures = newArray("RingLightBlock","BackLight","BackLightBrightnessLevel","DICShearingLevel");
	// notASCFeaturesDSXTitles = newArray("Ring Light Block","Back Light","Back Light BrightnessLevel","DIC ShearingLevel");
	settingsDSXTitles = newArray("Observation Method","Image Type","Objective Lens Magnification","Image Height \(pixels\)","Image Width \(pixels\)","Pixel Width  \(pm\)","Original Pixel Width  \(pm\)","Pixel Height \(pm\)","Original Pixel Height \(pm\)","Pixel Depth \(pixels\)","Original Pixel Depth \(pixels\)","Objective Lens Type","Zoom Magnification","Digital Zoom Magnification","Optical Zoom Magnification","Actual Magnification For 1x Zoom","Image Flip","Shading Correction","Image Aspect Ratio","Noise Reduction","Noise Reduction Level","Blur Correction","Blur Correction Value","Contrast Mode","Sharpness Mode","Field Curvature Correction","Stage Position X","Stage Position Y","Imaging AS","Analyzer Shearing Level","PBF","Camera Name","Gamma Correction Level");
	zSettingsDSX = newArray("ExtendMode","ZRangeMode","ZSliceTotal","ZSliceCount","ZStartPosition","ZEndPosition","ZRange","ZPitchTravel","HeightDataPerPixelZ");
	/* Note there is a typo in the Olympus section name: ObsevationSettingInfo[sic] so this may be corrected in the future */
	zSettingsDSXTitles = newArray("Focus steps mode", "ZRangeMode","ZSliceTotal","ZSliceCount","ZStartPosition","ZEndPosition","ZRange","ZPitchTravel","pm height/pixel");
	mapSettingsDSX = newArray("OverlapSize","StitchingRowCount","StitchingColumnCount","MapRoiTop","MapRoiLeft","MapRoiWidth","MapRoiHeight","ImageAspectRatio","ImageTrimmingSize");
	mapSettingsDSXTitles = newArray("Overlap Size","Stitching Row Count","Stitching Column Count","Map Roi Top","Map Roi Left","Map Roi Width","Map Roi Height","Image Aspect Ratio","Image Trimming Size");
	dsxEXIFData = getExifDataFromOpenImage();
	observationMethod = getDSXExifTagFromMetaData(dsxEXIFData,"ObservationMethod",true);
	if (observationMethod=="BF"){
		settingsDSX = Array.concat(settingsDSX,settingsDSXBF);
		settingsDSXTitles = Array.concat(settingsDSXTitles,settingsDSXBFTitles);
	}
	else if (observationMethod=="DF"){
		settingsDSX = Array.concat(settingsDSX,settingsDSXDF);
		settingsDSXTitles = Array.concat(settingsDSXTitles,settingsDSXDFTitles);
	}
	isMonochrome = toLowerCase(getDSXExifTagFromMetaData(dsxEXIFData,"IsMonochrome",true));
	if (isMonochrome){
		settingsDSX = Array.concat(settingsDSX,"IsMonochrome");
		settingsDSXTitles = Array.concat(settingsDSXTitles,"Is Monochrome",true);
	}
	else{
		settingsDSX = Array.concat(settingsDSX,settingsColor);
		settingsDSXTitles = Array.concat(settingsDSXTitles,settingsColorTitles);	
	}
	imageRotated = toLowerCase(getDSXExifTagFromMetaData(dsxEXIFData,"ImageRotation",true));
	if (imageRotated){
		settingsDSX = Array.concat(settingsDSX,"ImageRotationAngle");
		settingsDSXTitles = Array.concat(settingsDSXTitles,"Image Rotation Angle");
	}
	aeSetting = getDSXExifTagFromMetaData(dsxEXIFData,"AE",true);
	if (aeSetting=="true"){
		settingsDSX = Array.concat(settingsDSX,settingsDSXAE);
		settingsDSXTitles = Array.concat(settingsDSXTitles,settingsDSXAETitles);
	}
	hdrProcessing = getDSXExifTagFromMetaData(dsxEXIFData,"HDRProcessing",true);
	if (hdrProcessing=="true"){
		settingsDSX = Array.concat(settingsDSX,"HDRMode");
		settingsDSXTitles = Array.concat(settingsDSXTitles,"HDR Mode");
	}
	binning = getDSXExifTagFromMetaData(dsxEXIFData,"Binning",true);
	if (binning=="true"){
		settingsDSX = Array.concat(settingsDSX,"BinningLevel");
		settingsDSXTitles = Array.concat(settingsDSXTitles,"Binning Level");
	}
	imageType = getDSXExifTagFromMetaData(dsxEXIFData,"ImageType",true);
	if (endsWith(imageType,"ExtendHeight")){
		settingsDSX = Array.concat(settingsDSX,zSettingsDSX);
		settingsDSXTitles = Array.concat(settingsDSXTitles,zSettingsDSXTitles);
	}
	stitching = getDSXExifTagFromMetaData(dsxEXIFData,"Stitching",true);
	if (stitching){
		settingsDSX = Array.concat(settingsDSX,mapSettingsDSX);
		settingsDSXTitles = Array.concat(settingsDSXTitles,mapSettingsDSXTitles);	
	}
	for(i=0;i<settingsDSX.length;i++){
		tagReturned = getDSXExifTagFromMetaData(dsxEXIFData,settingsDSX[i],true);
		if (endsWith(tagReturned,"not found in metaData")){
			settingsDSX = Array.deleteIndex(settingsDSX, i);
			settingsDSXTitles = Array.deleteIndex(settingsDSXTitles, i);
		}
	}
	settingsN = lengthOf(settingsDSX);	
	settingsTitlesN = lengthOf(settingsDSXTitles);
	if (settingsN!=settingsTitlesN){
		IJ.log("Mismatch between " + settingsN + "header names and " + settingsTitlesN + "header titles");
		Array.print(settingsDSX);
		Array.print(settingsDSXTitles);
		exit("Mismatch between " + settingsN + "header names and " + settingsTitlesN + "header titles");
	}
	dsxEXIFData = getExifDataFromOpenImage();
	observationData = newArray();
	for(i=0; i<settingsN; i++){
		observationData[i] = getDSXExifTagFromMetaData(dsxEXIFData,settingsDSX[i],true);
		if (indexOf(settingsDSXTitles[i],"pm")>=0 || indexOf(settingsDSXTitles[i],"pixels")>=0) observationData[i] = parseInt(observationData[i]);
		else if (indexOf(settingsDSXTitles[i],"Zoom")>=0 || indexOf(settingsDSXTitles[i],"pixels")>=0) observationData[i] = d2s(observationData[i],3);
	}
	if (settingsN!=observationData.length) exit ("settings array, observation array length mismatch");
	filtObs = newArray();
	filtSett = newArray();
	filtSettTitles = newArray();
	for(i=0,j=0; i<observationData.length; i++){
		oD = observationData[i];
		if(!endsWith(oD,"not found") && oD!=NaN) {
			filtObs[j] = observationData[i];
			filtSett[j] = settingsDSX[i];
			filtSettTitles[j] = settingsDSXTitles[i];
			j++;
		}
	}
	if (filtObs.length!=settingsN){
			observationData = filtObs;
			settingsDSX = filtSett;
			settingsDSXTitles = filtSettTitles;
	}
	/* Generate combination labels */
	iWPx = indexOfArray(settingsDSX,"ImageWidth", -1);
	if (iWPx>=0) imageWidth = parseInt(observationData[iWPx]);
	cropped = false;
	if(imageCWidth!=imageWidth){
		cropped = true;
		observationData = Array.concat(imageCWidth,observationData);
		settingsDSX = Array.concat("imageCWidth",settingsDSX);		
		if(imageCWidth<imageWidth) settingsDSXTitles = Array.concat("Image cropped to width",settingsDSXTitles);
		else settingsDSXTitles = Array.concat("Image expanded to width",settingsDSXTitles);
	}
	if (iWPx<0) imageWidth = imageCWidth;
	iWPxPm = indexOfArray(settingsDSX,"ColorDataPerPixelX", -1);
	if (iWPxPm>=0) pxWidthMicrons = parseInt(observationData[iWPxPm]) * 10E-7;
	iWPxPmOr = indexOfArray(settingsDSX,"ImageDataPerPixelX", -1);
	if (iWPxPmOr>=0) pxWidthMicronsOr = parseInt(observationData[iWPxPmOr]) * 10E-7;
	iHPx = indexOfArray(settingsDSX,"ImageHeight", -1);
	if (iHPx>=0) imageHeight = maxOf(parseInt(observationData[iHPx]),getHeight());
	if(imageCHeight!=imageHeight){
		cropped = true;
		observationData = Array.concat(imageCHeight,observationData);
		settingsDSX = Array.concat("imageCHeight",settingsDSX);		
		if(imageCHeight<imageHeight) settingsDSXTitles = Array.concat("Image cropped to Height",settingsDSXTitles);
		else settingsDSXTitles = Array.concat("Image expanded to Height",settingsDSXTitles);
	}
	if (cropped==true){
		newCrop = "" + imageCWidth + " " + fromCharCode(0x00D7) + " " + imageCHeight;
		observationData = Array.concat(newCrop,observationData);
		settingsDSX = Array.concat("newCrop",settingsDSX);		
		if((imageCHeight+imageCWidth)<(imageHeight+imageWidth)) settingsDSXTitles = Array.concat("Image cropped to",settingsDSXTitles);
		else settingsDSXTitles = Array.concat("Image expanded to",settingsDSXTitles);
	}
	if (iWPx<0) imageHeight = imageCHeight;
	iHPxPm = indexOfArray(settingsDSX,"ColorDataPerPixelY", -1);		
	if (iHPxPm>=0) pxHeightMicrons = parseInt(observationData[iHPxPm]) * 10E-7;
	iHPxPmOr = indexOfArray(settingsDSX,"ImageDataPerPixelY", -1);		
	if (iHPxPmOr>=0){
		pxHeightMicronsOr = parseInt(observationData[iHPxPmOr]) * 10E-7;
		observationData = Array.concat(pxHeightMicronsOr,observationData);
		settingsDSXTitles = Array.concat("Original pixel height \("+um+"\)",settingsDSXTitles);
		settingsDSX = Array.concat("pxHeightMicronsOr",settingsDSX);
		if (iWPxPm>=0){
			resizeFactorFromOr = pxWidthMicronsOr/pxWidthMicrons;
			observationData = Array.concat(pxHeightMicrons,observationData);
			settingsDSXTitles = Array.concat("Image pixel height \("+um+"\)",settingsDSXTitles);
			settingsDSX = Array.concat("pxHeightMicrons",settingsDSX);
			if (resizeFactorFromOr!=1){
				observationData = Array.concat(resizeFactorFromOr,observationData);
				settingsDSXTitles = Array.concat("Image scaled from Original by",settingsDSXTitles);
				settingsDSX = Array.concat("resizeFactorFromOr",settingsDSX);
			}
		}
	}
	iObjMag = indexOfArray(settingsDSX,"ObjectiveLensMagnification", -1);
	iZoomMag = indexOfArray(settingsDSX,"ZoomMagnification", -1);
	iTrueObjZoomF =  indexOfArray(settingsDSX,"ActualMagnificationFor1xZoom", -1);
	if (iObjMag>=0 && iZoomMag>=0 && iTrueObjZoomF>=0){
		actualObjxZoomMag = d2s(parseFloat(observationData[iObjMag]) * parseFloat(observationData[iZoomMag]) * parseFloat(observationData[iTrueObjZoomF]),4);
		actualObjxZoomMagTitle = "Actual Objective " + fromCharCode(0x00D7) + " Zoom Magnification";
		observationData = Array.concat(actualObjxZoomMag,observationData);
		settingsDSXTitles = Array.concat(actualObjxZoomMagTitle,settingsDSXTitles);
		settingsDSX = Array.concat("actualObjxZoomMag",settingsDSX);
	}
	iDIntensityPm = indexOfArray(settingsDSX,"ColorDataPerPixelZ",-1);
	if (iDIntensityPm>=0){
		depthCal = parseFloat(observationData[iDIntensityPm]);
		if (depthCal>1){ 
			depthCalMicrons = depthCal * pow(10,-6);
			fullDepthRangeMicrons = d2s(256 * 256 * depthCalMicrons,3); /* depth map is 16-bit */
			observationData = Array.concat(depthCalMicrons,fullDepthRangeMicrons,observationData);
			depthCalMicronsTitle = "Height Map Calibration \(" + um + "\/intensity Level\)";
			fullDepthRangeMicronsTitle = "Full 16-bit Height Map Range \(" + um + "\)";
			settingsDSXTitles = Array.concat(depthCalMicronsTitle,fullDepthRangeMicronsTitle,settingsDSXTitles);
			settingsDSX = Array.concat("DepthCalMicrons","FullDepthRangeMicrons",settingsDSX);
		}
	} 
	iDIntensityPmOr = indexOfArray(settingsDSX,"ImageDataPerPixelZ",-1);
	if (iDIntensityPmOr>=0){
		depthCalOr = parseFloat(observationData[iDIntensityPmOr]);
		if (depthCalOr>1){ 
			depthCalMicronsOr = depthCalOr * pow(10,-6);
			fullDepthRangeMicronsOr = d2s(256 * 256 * depthCalMicronsOr,3); /* depth map is 16-bit */
			observationData = Array.concat(depthCalMicronsOr,fullDepthRangeMicronsOr,observationData);
			depthCalMicronsTitleOr = "Original Height Map Calibration \(" + um + "\/intensity Level\)";
			fullDepthRangeMicronsTitleOr = "Original Full 16-bit Height Map Range \(" + um + "\)";
			settingsDSXTitles = Array.concat(depthCalMicronsTitleOr,fullDepthRangeMicronsTitleOr,settingsDSXTitles);
			settingsDSX = Array.concat("DepthCalMicronsOr","FullDepthRangeMicronsOr",settingsDSX);
		}
	}
	if(iWPx>=0 && iWPxPm>=0 && iHPx>=0 && iHPxPm>=0){
		imageWMicrons = imageWidth * pxWidthMicrons;
		imageSizePix = d2s(imageWidth,0) + " " + fromCharCode(0x00D7) + " " + d2s(imageHeight,0);
		imageHMicrons = parseInt(imageHeight) * pxHeightMicrons;
		imageSizeMicrons = d2s(imageWMicrons,1) + " " + fromCharCode(0x00D7) + " " + d2s(imageHMicrons,1);
		if(!cropped){
			imageSizePixTitle = "Image size \(pixels\)";
			observationData = Array.concat(imageSizePix,imageSizeMicrons,observationData);
			imageSizeMicronsTitle = "Image size \(" + um + "\)";
			settingsDSXTitles = Array.concat(imageSizePixTitle,imageSizeMicronsTitle,settingsDSXTitles);
			settingsDSX = Array.concat("ImageSizePix","ImageSizeMicrons",settingsDSX);
		}
		else{
			imageCWMicrons = imageCWidth * pxWidthMicrons;
			imageCHMicrons = imageCHeight * pxHeightMicrons;
			imageCSizeMicrons = d2s(imageCWMicrons,1) + " " + fromCharCode(0x00D7) + " " + d2s(imageCHMicrons,1);
			observationData = Array.concat(imageCSizeMicrons,observationData);
			imageCSizeMicronsTitle = "Image size after crop \(" + um + "\)";
			settingsDSXTitles = Array.concat(imageCSizeMicronsTitle,settingsDSXTitles);
			settingsDSX = Array.concat("ImageCSizeMicrons",settingsDSX);
		}
	}
	else if(iWPxOr>=0 && iWPxPmOr>=0 && iHPxOr>=0 && iHPxPmOr>=0){
		imageWMicronsOr = parseInt(imageWidth) * pxWidthMicrons;
		imageSizePixOr = d2s(imageWidth,0) + " " + fromCharCode(0x00D7) + " " + d2s(imageHeight,0);
		imageSizePixTitleOr = "Original Image Size \(pixels\)";
		imageSizeMicronsTitleOr = "Image size \(" + um + "\)";
		imageHMicronsOr = parseInt(imageHeight) * pxHeightMicronsOr;
		imageSizeMicronsOr = d2s(imageWMicronsOr,1) + " " + fromCharCode(0x00D7) + " " + d2s(imageHMicronsOr,1);
		observationData = Array.concat(imageSizePixOr,imageSizeMicronsOr,observationData);
		settingsDSXTitles = Array.concat(imageSizePixTitleOr,imageSizeMicronsTitleOr,settingsDSXTitles);
		settingsDSX = Array.concat("OriginalImageSizePix","OriginalImageSizeMicrons",settingsDSX);
	}
	/* End of combination settings */
	observationData = Array.concat(imageTitle,observationData);
	imageTitleTitle = "Image Title";
	settingsDSXTitles = Array.concat(imageTitleTitle,settingsDSXTitles);
	/* Update settingsDSX array to match above to help call out default settings */
	settingsDSX = Array.concat("imageTitle",settingsDSX);
	dataN = lengthOf(observationData);
	titlesN = lengthOf(settingsDSXTitles);
	if (dataN!=titlesN) exit("Number of titles \("+titlesN+"\) does not equal number of settings \("+settingsN+"\)");
	observationLabels = newArray(dataN);
	for(i=0; i<dataN; i++) observationLabels[i] = settingsDSXTitles[i] + ": " + observationData[i];
	/* End of DSX parameter import */
	defaultLabelChecks = newArray(dataN);
	Array.fill(defaultLabelChecks,false);
	/* Now add checkboxes to default parameters */
	for(i=0; i<dataN; i++) if(indexOfArray(defaultSettings,settingsDSX[i],-1)>-1) defaultLabelChecks[i] = true;
	if (selectionType>=0) {
		selEType = selectionType; 
		selectionExists = true;
		getSelectionBounds(selEX, selEY, selEWidth, selEHeight);
	}
	else selectionExists = false;
	fontSize = maxOf(12,round(imageDims/140)); /* default font size is small for this variant */
	lineSpacing = 1.2;
	outlineStroke = 9; /* default outline stroke: % of font size */
	shadowDrop = 8;  /* default outer shadow drop: % of font size */
	dIShO = 5; /* default inner shadow drop: % of font size */
	shadowDisp = shadowDrop;
	shadowBlur = 1.1 * shadowDrop;
	shadowDarkness = 60;
	innerShadowDrop = dIShO;
	innerShadowDisp = dIShO;
	innerShadowBlur = floor(dIShO/2);
	innerShadowDarkness = 20;
	selOffsetX = round(1 + imageCWidth/150); /* default offset of label from edge */
	selOffsetY = round(1 + imageCHeight/150); /* default offset of label from edge */
	if (iWPxPm>=0){
		distPerPixel = pxWidthMicrons; /* Defaults to DSX output image, which is automatically resized if beyond a certain size */
		pxAspectRatio = pxWidthMicrons/pxHeightMicrons;
	} 
	else if (iWPxPmOr>=0){
		distPerPixel = pxWidthMicronsOr;
		pxAspectRatio = pxWidthMicronsOr/pxHeightMicronsOr;
	} 
	/* Then Dialog . . . */
	Dialog.create("Basic Label Options: " + macroL);
		if (iWPxPm>=0 || iWPxPmOr>=0){
			scaleText = "Apply scale of " + distPerPixel + " " + um + " per pixel";
			if (pxAspectRatio!=1)	scaleText += ", pixel aspect ratio of " + pxAspectRatio);
			Dialog.addCheckbox(scaleText,true);
		} 
		Dialog.addString("Optional list title \((leave blank for none\)","",50);
		Dialog.addMessage("Labels: ^2 & um etc. replaced by " + fromCharCode(178) + " & " + fromCharCode(181) + "m etc. If the units are in the parameter label, within \(...\) i.e. \(unit\) they will override this selection:");
		Dialog.addCheckboxGroup(1+dataN/3,3,observationLabels,defaultLabelChecks);
		Dialog.addRadioButtonGroup("Also output to log window?", newArray("No","Just selected","All parameters"),1,3,"Just selected");
		Dialog.addCheckbox("Copy metadata to new image if created",true);
		textLocChoices = newArray("Top Left", "Top Right", "Center", "Bottom Left", "Bottom Right", "Under", "Center of New Selection"); 
		iLoc = 0;
		if (selectionExists) {
			textLocChoices = Array.concat(textLocChoices, "At Selection"); 
			iLoc = 6;
		}
		Dialog.addChoice("Location:", textLocChoices, textLocChoices[iLoc]);
		Dialog.addMessage("If 'Under' is selected the parameters will be combined on a contrasting bar under the image");
		Dialog.addNumber("If 'Under' leave this space to right for scale bar or logo",25,0,3,"% of image width");
		if (selectionExists) {
			Dialog.addNumber("Selection Bounds: X start = ", selEX);
			Dialog.addNumber("Selection Bounds: Y start = ", selEY);
			Dialog.addNumber("Selection Bounds: Width = ", selEWidth);
			Dialog.addNumber("Selection Bounds: Height = ", selEHeight);
		}
		grayChoices = newArray("white", "black", "off-white", "off-black", "light_gray", "gray", "dark_gray");
		colorChoicesStd = newArray("red", "green", "blue", "cyan", "magenta", "yellow", "pink", "orange", "violet");
		colorChoicesMod = newArray("garnet", "gold", "aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "blue_honolulu", "gray_modern", "green_dark_modern", "green_modern", "green_modern_accent", "green_spring_accent", "orange_modern", "pink_modern", "purple_modern", "red_n_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern");
		colorChoicesNeon = newArray("jazzberry_jam", "radical_red", "wild_watermelon", "outrageous_orange", "supernova_orange", "atomic_tangerine", "neon_carrot", "sunglow", "laser_lemon", "electric_lime", "screamin'_green", "magic_mint", "blizzard_blue", "dodger_blue", "shocking_pink", "razzle_dazzle_rose", "hot_magenta");
		if (isMonochrome){
			if (imageDepth==24) Dialog.addCheckbox("Aquired image was monochrome, convert to 8-bit grayscale?",true);
			colorChoices = grayChoices;
		}
		else colorChoices = Array.concat(grayChoices, colorChoicesStd, colorChoicesMod, colorChoicesNeon);
		Dialog.addNumber("Font size:", fontSize, 0, 3,"");
		Dialog.setInsets(-30, 60, 0);
		Dialog.addChoice("Text color:", colorChoices, colorChoices[0]);
		fontStyleChoice = newArray("bold", "bold antialiased", "italic", "italic antialiased", "bold italic", "bold italic antialiased", "unstyled");
		Dialog.addChoice("Font style:", fontStyleChoice, fontStyleChoice[1]);
		fontNameChoice = getFontChoiceList();
		Dialog.addChoice("Font name:", fontNameChoice, fontNameChoice[0]);
		Dialog.addChoice("Outline color:", colorChoices, colorChoices[1]);
		Dialog.addCheckbox("Do not use outlines and shadows \(if 'Under' is selected for location, no outlines or shadows will be used\)",false);
		Dialog.addCheckbox("Tweak the Formatting?",false);
		Dialog.addCheckbox("Diagnostic output?",false);
/*	*/
	Dialog.show();
		if (iWPxPm>=0 || iWPxPmOr>=0){
			if (Dialog.getCheckbox()) run("Set Scale...", "distance=1 known=&distPerPixel pixel=&pxAspectRatio unit=um");
		}
		optionalLabel = Dialog.getString();
		chosenLabels = newArray();
		chosenParameters = newArray();
		for (i=0,j=0; i<dataN; i++){
			if (Dialog.getCheckbox){
				chosenLabels[j] = observationLabels[i];
				chosenParameters[j] = settingsDSX[i]; /* Use for saving prefs */
				j++;
			}
		}
		if (optionalLabel!="") chosenLabels = Array.concat(optionalLabel,chosenLabels);
		logOutput = Dialog.getRadioButton();
		transferMetadata = Dialog.getCheckbox();
		textLocChoice = Dialog.getChoice();
		underClear = Dialog.getNumber();
		if (selectionExists==1) {
			selEX =  Dialog.getNumber();
			selEY =  Dialog.getNumber();
			selEWidth =  Dialog.getNumber();
			selEHeight =  Dialog.getNumber();
		}
		if (isMonochrome){
			if (Dialog.getCheckbox()) run("8-bit");
		}
		fontSize =  Dialog.getNumber();
		selColor = Dialog.getChoice();
		fontStyle = Dialog.getChoice();
		fontName = Dialog.getChoice();
		outlineColor = Dialog.getChoice();
		notFancy = Dialog.getCheckbox(); 
		tweakFormat = Dialog.getCheckbox();
		diagnostics = Dialog.getCheckbox();
/*	*/
	if(diagnostics){
		IJ.log("observationData array \("+observationData.length+" entries\):");
		IJ.log("settingsDSXTitles array \("+settingsDSXTitles.length+" entries\):");
		IJ.log("settingsDSX array \("+settingsDSX.length+" entries\):");
		maxRows = maxOf(settingsDSX.length,maxOf(observationData.length,settingsDSXTitles.length));
		IJ.log("settingsDSXTitles,     settingsDSX,     observationData\n=============================================");
		for(i=0;i<maxRows;i++){
			row = "";
			if (i<settingsDSXTitles.length) row += "" + settingsDSXTitles[i] + ",     ";
			else row += "settingsDSXTitles " + i + ": Missing,";
			if (i<settingsDSX.length) row += "" + settingsDSX[i] + ",     ";
			else row += "settingsDSX " + i + ": Missing,";
			if (i<observationData.length) row += "" + observationData[i];
			else row += "observationDatas " + i + ": Missing";
			IJ.log(row);
		}
	}
	if(startsWith(logOutput,"Just")) for (i=0; i<lengthOf(chosenLabels); i++) print(chosenLabels[i]);
	if(startsWith(logOutput,"All")) for (i=0; i<lengthOf(observationLabels); i++) print(observationLabels[i]);
	if(!startsWith(logOutput,"No")) print("------------\n");
	if (textLocChoice=="Under") notFancy = true;
	if (tweakFormat) {	
		Dialog.create("Advanced Formatting Options");
		Dialog.addNumber("X offset from edge \(for corners only\)", selOffsetX,0,1,"pixels");
		Dialog.addNumber("Y offset from edge \(for corners only\)", selOffsetY,0,1,"pixels");
		Dialog.addNumber("Line Spacing", lineSpacing,0,3,"");
		if(!notFancy) {
			Dialog.addNumber("Outline stroke:", outlineStroke,0,3,"% of font size");
			Dialog.addChoice("Outline (background) color:", colorChoices, colorChoices[1]);
			Dialog.addNumber("Shadow drop: ±", shadowDrop,0,3,"% of font size");
			Dialog.addNumber("Shadow displacement right: ±", shadowDrop,0,3,"% of font size");
			Dialog.addNumber("Shadow Gaussian blur:", floor(0.75 * shadowDrop),0,3,"% of font size");
			Dialog.addNumber("Shadow Darkness:", 75,0,3,"%\(darkest = 100%\)");
			// Dialog.addMessage("The following \"Inner Shadow\" options do not change the Overlay Labels");
			Dialog.addNumber("Inner shadow drop: ±", dIShO,0,3,"% of font size");
			Dialog.addNumber("Inner displacement right: ±", dIShO,0,3,"% of font size");
			Dialog.addNumber("Inner shadow mean blur:",floor(dIShO/2),1,3,"% of font size");
			Dialog.addNumber("Inner Shadow Darkness:", 20,0,3,"% \(darkest = 100%\)");
		}
		Dialog.show();
		selOffsetX = Dialog.getNumber();
		selOffsetY = Dialog.getNumber();
		lineSpacing = Dialog.getNumber();
		if(!notFancy) {
			outlineStroke = Dialog.getNumber();
			outlineColor = Dialog.getChoice();
			shadowDrop = Dialog.getNumber();
			shadowDisp = Dialog.getNumber();
			shadowBlur = Dialog.getNumber();
			shadowDarkness = Dialog.getNumber();
			innerShadowDrop = Dialog.getNumber();
			innerShadowDisp = Dialog.getNumber();
			innerShadowBlur = Dialog.getNumber();
			innerShadowDarkness = Dialog.getNumber();
		}
	}
	if(!notFancy) {
		negAdj = 0.5;  /* negative offsets appear exaggerated at full displacement */
		if (shadowDrop<0) shadowDrop *= negAdj;
		if (shadowDisp<0) shadowDisp *= negAdj;
		if (shadowBlur<0) shadowBlur *= negAdj;
		if (innerShadowDrop<0) innerShadowDrop *= negAdj;
		if (innerShadowDisp<0) innerShadowDisp *= negAdj;
		if (innerShadowBlur<0) innerShadowBlur *= negAdj;
	}
	fontFactor = fontSize/100;
	if(!notFancy) {
		outlineStroke = floor(fontFactor * outlineStroke);
		shadowDrop = floor(fontFactor * shadowDrop);
		shadowDisp = floor(fontFactor * shadowDisp);
		shadowBlur = floor(fontFactor * shadowBlur);
		innerShadowDrop = floor(fontFactor * innerShadowDrop);
		innerShadowDisp = floor(fontFactor * innerShadowDisp);
		innerShadowBlur = floor(fontFactor * innerShadowBlur);
	}
	if (fontStyle=="unstyled") fontStyle="";
	textChoiceLines = lengthOf(chosenLabels);
	setFont(fontName, fontSize, fontStyle);
	longestStringWidth = 0;
	if(textLocChoice=="under"){
		underLabels = newArray("");
		newLine = "";
		lineStart = selOffsetX;
		for (i=0,j=0; i<textChoiceLines; i++){
			labelLength = getStringWidth(chosenLabels[i]);
			if (labelLength>longestStringWidth) longestStringWidth = labelLength;
			if(textLocChoice=="under"){
				if (lineStart + selOffsetX + labelLength + 4 < ((100-underClear)*imageCWidth/100)){
					newLine += chosenLabels[i];
					underLabels[j] = newLine;
					newLine += "    ";
					lineStart = getStringWidth(newLine);
				}
				else {
					newLine = chosenLabels[i] + "    ";
					j++;
					underLabels[j] = newLine;
					lineStart = selOffsetX;
				}
			}
		}
		underLabelsN = j+1;
		linesSpace = lineSpacing * underLabelsN * fontSize;
	}
	else linesSpace = lineSpacing * (textChoiceLines) * fontSize;
	if (textLocChoice == "Top Left") {
		selEX = selOffsetX;
		selEY = selOffsetY;
	} else if (textLocChoice == "Top Right") {
		selEX = imageCWidth - longestStringWidth - selOffsetX;
		selEY = selOffsetY;
	} else if (textLocChoice == "Center") {
		selEX = round((imageCWidth - longestStringWidth)/2);
		selEY = round((imageCHeight - linesSpace)/2);
	} else if (textLocChoice == "Bottom Left") {
		selEX = selOffsetX;
		selEY = imageCHeight - (selOffsetY + linesSpace);
	} else if (textLocChoice == "Under") {
		selEX = selOffsetX;
		selEY = imageCHeight + selOffsetY +  fontSize + lineSpacing;	
	} else if (textLocChoice == "Bottom Right") {
		selEX = imageCWidth - longestStringWidth - selOffsetX;
		selEY = imageCHeight - (selOffsetY + linesSpace);
	} else if (textLocChoice == "Center of New Selection"){
		setTool("rectangle");
		if (is("Batch Mode")==true) setBatchMode(false); /* Does not accept interaction while batch mode is on */
		msgtitle="Location for the text labels...";
		msg = "Draw a box in the image where you want to center the text labels...";
		waitForUser(msgtitle, msg);
		getSelectionBounds(newSelEX, newSelEY, newSelEWidth, newSelEHeight);
		selEX = newSelEX + round((newSelEWidth/2) - longestStringWidth/1.5);
		selEY = newSelEY + round((newSelEHeight/2) - (linesSpace/2));
		if (is("Batch Mode")==false) setBatchMode(true);	/* toggle batch mode back on */
	} else if (selectionExists==1) {
		selEX = selEX + round((selEWidth/2) - longestStringWidth/1.5);
		selEY = selEY + round((selEHeight/2) - (linesSpace/2));
	}
	run("Select None");
	if (selEY<=1.5*fontSize)
		selEY += fontSize;
	if (selEX<selOffsetX) selEX = selOffsetX;
	endX = selEX + longestStringWidth;
	if ((endX+selOffsetX)>imageCWidth) selEX = imageCWidth - longestStringWidth - selOffsetX;
	textLabelX = selEX;
	textLabelY = selEY;
	setBatchMode(true);
	roiManager("show none");
	run("Duplicate...", imageTitle + "+text");
	if (transferMetadata) setMetadata("Info",dsxEXIFData);
	labeledImage = getTitle();
	setFont(fontName,fontSize, fontStyle);
	if(textLocChoice=="Under"){
		newHeight = imageCHeight + (2 * selOffsetY + (fontSize + lineSpacing) * (underLabelsN + 0.5));
		selColors = getColorArrayFromColorName(selColor);
		Array.getStatistics(selColors,null,null,meanSelColInt,null);
		if (meanSelColInt<128) run("Colors...", "background=white");
		else run("Colors...", "background=black");
		run("Canvas Size...", "width=[imageCWidth] height=[newHeight] position=Top-Center");
		run ("Colors...", "background=white");
	}
	if(!notFancy) {
		newImage("label_mask", "8-bit black", imageCWidth, imageCHeight, 1);
		roiManager("deselect");
		run("Select None");
		/* Draw summary over top of labels */
		setColor(255,255,255);
		xStart = textLabelX;
		for (i=0; i<textChoiceLines; i++) {
			if (textLocChoice == "Top Right" || textLocChoice == "Bottom Right")
				xStart = (textLabelX + longestStringWidth - getStringWidth(chosenLabels[i]));
			drawString(chosenLabels[i], xStart, textLabelY);
			textLabelY += (lineSpacing * fontSize);
		}
		setThreshold(0, 128);
		setOption("BlackBackground", false);
		run("Convert to Mask");
		/* Create drop shadow if desired */
		if (shadowDrop!=0 || shadowDisp!=0 || shadowBlur!=0)
			createShadowDropFromMask();
		// setBatchMode("exit & display");
		/* Create inner shadow if desired */
		if (innerShadowDrop!=0 || innerShadowDisp!=0 || innerShadowBlur!=0)
			createInnerShadowFromMask();
		if (isOpen("shadow") && shadowDarkness>0)
			imageCalculator("Subtract", labeledImage,"shadow");
		if (isOpen("shadow") && shadowDarkness<0)
			imageCalculator("Subtract", labeledImage,"shadow"); /* glow */
		run("Select None");
		getSelectionFromMask("label_mask");
		run("Enlarge...", "enlarge=[outlineStroke] pixel");
		setBackgroundFromColorName(outlineColor);
		run("Clear");
		run("Select None");
		getSelectionFromMask("label_mask");
		setBackgroundFromColorName(selColor);
		run("Clear");
		run("Select None");
		if (isOpen("inner_shadow")) imageCalculator("Subtract", labeledImage,"inner_shadow");
		closeImageByTitle("shadow");
		closeImageByTitle("inner_shadow");
		closeImageByTitle("label_mask");
		selectWindow(labeledImage);
	}
	else {
		colorHex = getHexColorFromColorName(selColor);
		setColor(colorHex);
		xStart = textLabelX;
		if(textLocChoice=="under"){
			for (i=0; i<underLabelsN; i++) {
				drawString(underLabels[i], xStart, textLabelY);
				textLabelY += lineSpacing * fontSize;
			}
		}
		else {
			for (i=0; i<textChoiceLines; i++) {
				if (textLocChoice == "Top Right" || textLocChoice == "Bottom Right")
					xStart = (textLabelX + longestStringWidth - getStringWidth(chosenLabels[i]));
				if(textLocChoice=="under") drawString(underLabels[i], xStart, textLabelY);
				else drawString(chosenLabels[i], xStart, textLabelY);
				textLabelY += lineSpacing * fontSize;
			}
		}
	}
	/* now rename image to reflect changes and avoid danger of overwriting original */
	labeledImageNameWOExt = unCleanLabel(stripKnownExtensionFromString(labeledImage));
	rename(labeledImageNameWOExt + "_SettingLabels");
	prefsParametersString = arrayToString(chosenParameters,prefsDelimiter);
	call("ij.Prefs.set", prefsNameKey+"lastParameters", prefsParametersString);
	setBatchMode("exit & display");
	showStatus("Fancy DSX annotation macro finished");
/* 
	( 8(|)	( 8(|)	Functions	@@@@@:-)	@@@@@:-)
*/
	function arrayToString(array,delimiter){
		/* 1st version April 2019 PJL
			v190722 Modified to handle zero length array
			v220307 += restored for else line*/
		string = "";
		for (i=0; i<array.length; i++){
			if (i==0) string += array[0];
			else  string += delimiter + array[i];
		}
		return string;
	}
	function cleanLabel(string) {
		/*  ImageJ macro default file encoding (ANSI or UTF-8) varies with platform so non-ASCII characters may vary: hence the need to always use fromCharCode instead of special characters.
		v180611 added "degreeC"
		v200604	fromCharCode(0x207B) removed as superscript hyphen not working reliably
		v220630 added degrees v220812 Changed Ångström unit code
		v231005 Weird Excel characters added, micron unit correction */
		string= replace(string, "\\^2", fromCharCode(178)); /* superscript 2 */
		string= replace(string, "\\^3", fromCharCode(179)); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, "\\^-"+fromCharCode(185), "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-"+fromCharCode(178), "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-^1", "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-^2", "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-1", "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-2", "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "\\^-^1", "-" + fromCharCode(185)); /* superscript -1 */
		string= replace(string, "\\^-^2", "-" + fromCharCode(178)); /* superscript -2 */
		string= replace(string, "(?<![A-Za-z0-9])u(?=m)", fromCharCode(181)); /* micron units */
		string= replace(string, "\\b[aA]ngstrom\\b", fromCharCode(0x212B)); /* Ångström unit symbol */
		string= replace(string, "  ", " "); /* Replace double spaces with single spaces */
		string= replace(string, "_", " "); /* Replace underlines with space as thin spaces (fromCharCode(0x2009)) not working reliably  */
		string= replace(string, "px", "pixels"); /* Expand pixel abbreviation */
		string= replace(string, "degreeC", fromCharCode(0x00B0) + "C"); /* Degree symbol for dialog boxes */
		// string = replace(string, " " + fromCharCode(0x00B0), fromCharCode(0x2009) + fromCharCode(0x00B0)); /* Replace normal space before degree symbol with thin space */
		// string= replace(string, " °", fromCharCode(0x2009) + fromCharCode(0x00B0)); /* Replace normal space before degree symbol with thin space */
		string= replace(string, "sigma", fromCharCode(0x03C3)); /* sigma for tight spaces */
		string= replace(string, "plusminus", fromCharCode(0x00B1)); /* plus or minus */
		string= replace(string, "degrees", fromCharCode(0x00B0)); /* plus or minus */
		if (indexOf(string,"mý")>1) string = substring(string, 0, indexOf(string,"mý")-1) + getInfo("micrometer.abbreviation") + fromCharCode(178);
		return string;
	}
	function closeImageByTitle(windowTitle) {  /* Cannot be used with tables */
		/* v181002 reselects original image at end if open
		   v200925 uses "while" instead of if so it can also remove duplicates
		*/
		oIID = getImageID();
        while (isOpen(windowTitle)) {
			selectWindow(windowTitle);
			close();
		}
		if (isOpen(oIID)) selectImage(oIID);
	}
	function createInnerShadowFromMask() {
		/* Requires previous run of: imageDepth = bitDepth();
		because this version works with different bitDepths
		v161104
		v200706 changed image depth variable name.
		*/
		showStatus("Creating inner shadow for labels . . . ");
		newImage("inner_shadow", "8-bit white", imageCWidth, imageCHeight, 1);
		getSelectionFromMask("label_mask");
		setBackgroundColor(0,0,0);
		run("Clear Outside");
		getSelectionBounds(selMaskX, selMaskY, selMaskWidth, selMaskHeight);
		setSelectionLocation(selMaskX-innerShadowDisp, selMaskY-innerShadowDrop);
		setBackgroundColor(0,0,0);
		run("Clear Outside");
		getSelectionFromMask("label_mask");
		expansion = abs(innerShadowDisp) + abs(innerShadowDrop) + abs(innerShadowBlur);
		if (expansion>0) run("Enlarge...", "enlarge=[expansion] pixel");
		if (innerShadowBlur>0) run("Gaussian Blur...", "sigma=[innerShadowBlur]");
		run("Unsharp Mask...", "radius=0.5 mask=0.2"); /* A tweak to sharpen the effect for small font sizes */
		imageCalculator("Max", "inner_shadow","label_mask");
		run("Select None");
		/* The following are needed for different bit depths */
		if (imageDepth==16 || imageDepth==32) run(imageDepth + "-bit");
		run("Enhance Contrast...", "saturated=0 normalize");
		run("Invert");  /* Create an image that can be subtracted - this works better for color than Min */
		divider = (100 / abs(innerShadowDarkness));
		run("Divide...", "value=[divider]");
	}
	function createShadowDropFromMask() {
		/* Requires previous run of: imageDepth = bitDepth();
		because this version works with different bitDepths
		v161104 */
		showStatus("Creating drop shadow for labels . . . ");
		newImage("shadow", "8-bit black", imageCWidth, imageCHeight, 1);
		getSelectionFromMask("label_mask");
		getSelectionBounds(selMaskX, selMaskY, selMaskWidth, selMaskHeight);
		setSelectionLocation(selMaskX+shadowDisp, selMaskY+shadowDrop);
		setBackgroundColor(255,255,255);
		if (outlineStroke>0) run("Enlarge...", "enlarge=[outlineStroke] pixel"); /* Adjust shadow size so that shadow extends beyond stroke thickness */
		run("Clear");
		run("Select None");
		if (shadowBlur>0) {
			run("Gaussian Blur...", "sigma=[shadowBlur]");
			// run("Unsharp Mask...", "radius=[shadowBlur] mask=0.4"); // Make Gaussian shadow edge a little less fuzzy
		}
		/* Now make sure shadow or glow does not impact outline */
		getSelectionFromMask("label_mask");
		if (outlineStroke>0) run("Enlarge...", "enlarge=[outlineStroke] pixel");
		setBackgroundColor(0,0,0);
		run("Clear");
		run("Select None");
		/* The following are needed for different bit depths */
		if (imageDepth==16 || imageDepth==32) run(imageDepth + "-bit");
		run("Enhance Contrast...", "saturated=0 normalize");
		divider = (100 / abs(shadowDarkness));
		run("Divide...", "value=[divider]");
	}
	function getDSXExifTagFromMetaData(metaData,tagName,lastInstance) {
	/* metaData is string generated by metaData = getMetadata("Info");	
		v230120: 1st version  version b
		v230526: This version has "lastInstance" option
	*/
		tagBegin = "<"+tagName+">";
		if (!lastInstance) i0 = indexOf(metaData,tagBegin);
		else  i0 = lastIndexOf(metaData,tagBegin);
		if (i0!=-1) {
			tagEnd = "</" + tagName + ">";
			i1 = indexOf(metaData,tagEnd,i0);
			tagLine = substring(metaData,i0,i1);
			tagValue = substring(tagLine,indexOf(tagLine,">")+1,tagLine.length);
		}
		else tagValue = "" + tagName + " not found in metaData";
		return tagValue;
	}
	function getExifDataFromOpenImage(){
		/* uses exifReader plugin: https://imagej.nih.gov/ij/plugins/exif-reader.html
		The exif reader plugin will not load a new image directly if one is open, it will only use the open image
		- this is why this version opens a new image separately
		v230512: 1st version
		v230526: Shorter */
		exifTitle = "EXIF Metadata for " + getTitle();
		run("Exif Data...");
		wait(10);
		selectWindow(exifTitle);
		metaInfo = getInfo("window.contents");
		close(exifTitle);
		return metaInfo;
	}
	/*
	Color Functions	Based on BAR Utilities: https://imagej.net/plugins/bar
	Ferreira, T., Miura, K., Bitdeli Chef, & Eglinger, J. (2015). Scripts: BAR 1.1.6 (Version 1.1.6). Zenodo. doi:10.5281/ZENODO.28838
	*/
	function getColorArrayFromColorName(colorName) {
		/* v180828 added Fluorescent Colors
		   v181017-8 added off-white and off-black for use in gif transparency and also added safe exit if no color match found
		   v191211 added Cyan
		   v211022 all names lower-case, all spaces to underscores v220225 Added more hash value comments as a reference v220706 restores missing magenta
		   v230130 Added more descriptions and modified order.
		   v230908: Returns "white" array if not match is found and logs issues without exiting.
		     57 Colors 
		*/
		functionL = "getColorArrayFromColorName_v230911";
		cA = newArray(255,255,255); /* defaults to white */
		if (colorName == "white") cA = newArray(255,255,255);
		else if (colorName == "black") cA = newArray(0,0,0);
		else if (colorName == "off-white") cA = newArray(245,245,245);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "red") cA = newArray(255,0,0);
		else if (colorName == "green") cA = newArray(0,255,0);					/* #00FF00 AKA Lime green */
		else if (colorName == "blue") cA = newArray(0,0,255);
		else if (colorName == "cyan") cA = newArray(0, 255, 255);
		else if (colorName == "yellow") cA = newArray(255,255,0);
		else if (colorName == "magenta") cA = newArray(255,0,255);				/* #FF00FF */
		else if (colorName == "pink") cA = newArray(255, 192, 203);
		else if (colorName == "violet") cA = newArray(127,0,255);
		else if (colorName == "orange") cA = newArray(255, 165, 0);
		else if (colorName == "garnet") cA = newArray(120,47,64);				/* #782F40 */
		else if (colorName == "gold") cA = newArray(206,184,136);				/* #CEB888 */
		else if (colorName == "aqua_modern") cA = newArray(75,172,198);		/* #4bacc6 AKA "Viking" aqua */
		else if (colorName == "blue_accent_modern") cA = newArray(79,129,189); /* #4f81bd */
		else if (colorName == "blue_dark_modern") cA = newArray(31,73,125);	/* #1F497D */
		else if (colorName == "blue_honolulu") cA = newArray(0,118,182);		/* Honolulu Blue #006db0 */
		else if (colorName == "blue_modern") cA = newArray(58,93,174);			/* #3a5dae */
		else if (colorName == "gray_modern") cA = newArray(83,86,90);			/* bright gray #53565A */
		else if (colorName == "green_dark_modern") cA = newArray(121,133,65);	/* Wasabi #798541 */
		else if (colorName == "green_modern") cA = newArray(155,187,89);		/* #9bbb59 AKA "Chelsea Cucumber" */
		else if (colorName == "green_modern_accent") cA = newArray(214,228,187); /* #D6E4BB AKA "Gin" */
		else if (colorName == "green_spring_accent") cA = newArray(0,255,102);	/* #00FF66 AKA "Spring Green" */
		else if (colorName == "orange_modern") cA = newArray(247,150,70);		/* #f79646 tan hide, light orange */
		else if (colorName == "pink_modern") cA = newArray(255,105,180);		/* hot pink #ff69b4 */
		else if (colorName == "purple_modern") cA = newArray(128,100,162);		/* blue-magenta, purple paradise #8064A2 */
		else if (colorName == "jazzberry_jam") cA = newArray(165,11,94);
		else if (colorName == "red_n_modern") cA = newArray(227,24,55);
		else if (colorName == "red_modern") cA = newArray(192,80,77);
		else if (colorName == "tan_modern") cA = newArray(238,236,225);
		else if (colorName == "violet_modern") cA = newArray(76,65,132);
		else if (colorName == "yellow_modern") cA = newArray(247,238,69);
		/* Fluorescent Colors https://www.w3schools.com/colors/colors_crayola.asp */
		else if (colorName == "radical_red") cA = newArray(255,53,94);			/* #FF355E */
		else if (colorName == "wild_watermelon") cA = newArray(253,91,120);	/* #FD5B78 */
		else if (colorName == "shocking_pink") cA = newArray(255,110,255);		/* #FF6EFF Ultra Pink */
		else if (colorName == "razzle_dazzle_rose") cA = newArray(238,52,210);	/* #EE34D2 */
		else if (colorName == "hot_magenta") cA = newArray(255,0,204);			/* #FF00CC AKA Purple Pizzazz */
		else if (colorName == "outrageous_orange") cA = newArray(255,96,55);	/* #FF6037 */
		else if (colorName == "supernova_orange") cA = newArray(255,191,63);	/* FFBF3F Supernova Neon Orange*/
		else if (colorName == "sunglow") cA = newArray(255,204,51);			/* #FFCC33 */
		else if (colorName == "neon_carrot") cA = newArray(255,153,51);		/* #FF9933 */
		else if (colorName == "atomic_tangerine") cA = newArray(255,153,102);	/* #FF9966 */
		else if (colorName == "laser_lemon") cA = newArray(255,255,102);		/* #FFFF66 "Unmellow Yellow" */
		else if (colorName == "electric_lime") cA = newArray(204,255,0);		/* #CCFF00 */
		else if (colorName == "screamin'_green") cA = newArray(102,255,102);	/* #66FF66 */
		else if (colorName == "magic_mint") cA = newArray(170,240,209);		/* #AAF0D1 */
		else if (colorName == "blizzard_blue") cA = newArray(80,191,230);		/* #50BFE6 Malibu */
		else if (colorName == "dodger_blue") cA = newArray(9,159,255);			/* #099FFF Dodger Neon Blue */
		else IJ.log(colorName + " not found in " + functionL + ": Color defaulted to white");
		return cA;
	}
	function setBackgroundFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setBackgroundColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function setColorFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function setForegroundColorFromName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setForegroundColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	/* Hex conversion below adapted from T.Ferreira, 20010.01 https://imagej.net/doku.php?id=macro:rgbtohex */
	function getHexColorFromColorName(colorNameString) {
		/* v231207: Uses IJ String.pad instead of function: pad */
		colorArray = getColorArrayFromColorName(colorNameString);
		 r = toHex(colorArray[0]); g = toHex(colorArray[1]); b = toHex(colorArray[2]);
		 hexName= "#" + "" + String.pad(r, 2) + "" + String.pad(g, 2) + "" + String.pad(b, 2);
		 return hexName;
	}	
		
	/*	End of BAR-based Color Functions	*/
	
  	function getFontChoiceList() {
		/*	v180723 first version
			v180828 Changed order of favorites. v190108 Longer list of favorites. v230209 Minor optimization.
			v230919 You can add a list of fonts that do not produce good results with the macro. 230921 more exclusions.
		*/
		systemFonts = getFontList();
		IJFonts = newArray("SansSerif", "Serif", "Monospaced");
		fontNameChoices = Array.concat(IJFonts,systemFonts);
		blackFonts = Array.filter(fontNameChoices, "([A-Za-z]+.*[bB]l.*k)");
		eBFonts = Array.filter(fontNameChoices,  "([A-Za-z]+.*[Ee]xtra.*[Bb]old)");
		uBFonts = Array.filter(fontNameChoices,  "([A-Za-z]+.*[Uu]ltra.*[Bb]old)");
		fontNameChoices = Array.concat(blackFonts, eBFonts, uBFonts, fontNameChoices); /* 'Black' and Extra and Extra Bold fonts work best */
		faveFontList = newArray("Your favorite fonts here", "Arial Black", "Myriad Pro Black", "Myriad Pro Black Cond", "Noto Sans Blk", "Noto Sans Disp Cond Blk", "Open Sans ExtraBold", "Roboto Black", "Alegreya Black", "Alegreya Sans Black", "Tahoma Bold", "Calibri Bold", "Helvetica", "SansSerif", "Calibri", "Roboto", "Tahoma", "Times New Roman Bold", "Times Bold", "Goldman Sans Black", "Goldman Sans", "Serif");
		/* Some fonts or font families don't work well with ASC macros, typically they do not support all useful symbols, they can be excluded here using the .* regular expression */
		offFontList = newArray("Alegreya SC Black", "Archivo.*", "Arial Rounded.*", "Bodon.*", "Cooper.*", "Eras.*", "Fira.*", "Gill Sans.*", "Lato.*", "Libre.*", "Lucida.*",  "Merriweather.*", "Montserrat.*", "Nunito.*", "Olympia.*", "Poppins.*", "Rockwell.*", "Tw Cen.*", "Wingdings.*", "ZWAdobe.*"); /* These don't work so well. Use a ".*" to remove families */
		faveFontListCheck = newArray(faveFontList.length);
		for (i=0,counter=0; i<faveFontList.length; i++) {
			for (j=0; j<fontNameChoices.length; j++) {
				if (faveFontList[i] == fontNameChoices[j]) {
					faveFontListCheck[counter] = faveFontList[i];
					j = fontNameChoices.length;
					counter++;
				}
			}
		}
		faveFontListCheck = Array.trim(faveFontListCheck, counter);
		for (i=0; i<fontNameChoices.length; i++) {
			for (j=0; j<offFontList.length; j++){
				if (fontNameChoices[i]==offFontList[j]) fontNameChoices = Array.deleteIndex(fontNameChoices, i);
				if (endsWith(offFontList[j],".*")){
					if (startsWith(fontNameChoices[i], substring(offFontList[j], 0, indexOf(offFontList[j],".*")))){
						fontNameChoices = Array.deleteIndex(fontNameChoices, i);
						i = maxOf(0, i-1); 
					} 
					// fontNameChoices = Array.filter(fontNameChoices, "(^" + offFontList[j] + ")"); /* RegEx not working and very slow */
				} 
			} 
		}
		fontNameChoices = Array.concat(faveFontListCheck, fontNameChoices);
		for (i=0; i<fontNameChoices.length; i++) {
			for (j=i+1; j<fontNameChoices.length; j++)
				if (fontNameChoices[i]==fontNameChoices[j]) fontNameChoices = Array.deleteIndex(fontNameChoices, j);
		}
		return fontNameChoices;
	}
	function getSelectionFromMask(sel_M){
		/* v220920 only inverts if full width */
		batchMode = is("Batch Mode"); /* Store batch status mode before toggling */
		if (!batchMode) setBatchMode(true); /* Toggle batch mode on if previously off */
		tempID = getImageID();
		selectWindow(sel_M);
		run("Create Selection"); /* Selection inverted perhaps because the mask has an inverted LUT? */
		getSelectionBounds(gSelX,gSelY,gWidth,gHeight);
		if(gSelX==0 && gSelY==0 && gWidth==Image.width && gHeight==Image.height)	run("Make Inverse");
		run("Select None");
		selectImage(tempID);
		run("Restore Selection");
		if (!batchMode) setBatchMode(false); /* Return to original batch mode setting */
	}
	function indexOfArray(array, value, default) {
		/* v190423 Adds "default" parameter (use -1 for backwards compatibility). Returns only first found value
			v230902 Limits default value to array size */
		index = minOf(lengthOf(array) - 1, default);
		for (i=0; i<lengthOf(array); i++){
			if (array[i]==value) {
				index = i;
				i = lengthOf(array);
			}
		}
	  return index;
	}
	function memFlush(waitTime) {
		run("Reset...", "reset=[Undo Buffer]"); 
		wait(waitTime);
		run("Reset...", "reset=[Locked Image]"); 
		wait(waitTime);
		call("java.lang.System.gc"); /* force a garbage collection */
		wait(waitTime);
	}
	function stripKnownExtensionFromString(string) {
		/*	Note: Do not use on path as it may change the directory names
		v210924: Tries to make sure string stays as string.	v211014: Adds some additional cleanup.	v211025: fixes multiple 'known's issue.	v211101: Added ".Ext_" removal.
		v211104: Restricts cleanup to end of string to reduce risk of corrupting path.	v211112: Tries to fix trapped extension before channel listing. Adds xlsx extension.
		v220615: Tries to fix the fix for the trapped extensions ...	v230504: Protects directory path if included in string. Only removes doubled spaces and lines.
		v230505: Unwanted dupes replaced by unusefulCombos.	v230607: Quick fix for infinite loop on one of while statements.
		v230614: Added AVI.	v230905: Better fix for infinite loop. v230914: Added BMP and "_transp" and rearranged
		*/
		fS = File.separator;
		string = "" + string;
		protectedPathEnd = lastIndexOf(string,fS)+1;
		if (protectedPathEnd>0){
			protectedPath = substring(string,0,protectedPathEnd);
			string = substring(string,protectedPathEnd);
		}
		unusefulCombos = newArray("-", "_"," ");
		for (i=0; i<lengthOf(unusefulCombos); i++){
			for (j=0; j<lengthOf(unusefulCombos); j++){
				combo = unusefulCombos[i] + unusefulCombos[j];
				while (indexOf(string,combo)>=0) string = replace(string,combo,unusefulCombos[i]);
			}
		}
		if (lastIndexOf(string, ".")>0 || lastIndexOf(string, "_lzw")>0) {
			knownExts = newArray(".avi", ".csv", ".bmp", ".dsx", ".gif", ".jpg", ".jpeg", ".jp2", ".png", ".tif", ".txt", ".xlsx");
			knownExts = Array.concat(knownExts,knownExts,"_transp","_lzw");
			kEL = knownExts.length;
			for (i=0; i<kEL/2; i++) knownExts[i] = toUpperCase(knownExts[i]);
			chanLabels = newArray(" \(red\)"," \(green\)"," \(blue\)","\(red\)","\(green\)","\(blue\)");
			for (i=0,k=0; i<kEL; i++) {
				for (j=0; j<chanLabels.length; j++){ /* Looking for channel-label-trapped extensions */
					iChanLabels = lastIndexOf(string, chanLabels[j])-1;
					if (iChanLabels>0){
						preChan = substring(string,0,iChanLabels);
						postChan = substring(string,iChanLabels);
						while (indexOf(preChan,knownExts[i])>0){
							preChan = replace(preChan,knownExts[i],"");
							string =  preChan + postChan;
						}
					}
				}
				while (endsWith(string,knownExts[i])) string = "" + substring(string, 0, lastIndexOf(string, knownExts[i]));
			}
		}
		unwantedSuffixes = newArray(" ", "_","-");
		for (i=0; i<unwantedSuffixes.length; i++){
			while (endsWith(string,unwantedSuffixes[i])) string = substring(string,0,string.length-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
		}
		if (protectedPathEnd>0){
			if(!endsWith(protectedPath,fS)) protectedPath += fS;
			string = protectedPath + string;
		}
		return string;
	}
	function unCleanLabel(string) {
	/* v161104 This function replaces special characters with standard characters for file system compatible filenames.
	+ 041117b to remove spaces as well.
	+ v220126 added getInfo("micrometer.abbreviation").
	+ v220128 add loops that allow removal of multiple duplication.
	+ v220131 fixed so that suffix cleanup works even if extensions are included.
	+ v220616 Minor index range fix that does not seem to have an impact if macro is working as planned. v220715 added 8-bit to unwanted dupes. v220812 minor changes to micron and Ångström handling
	+ v231005 Replaced superscript abbreviations that did not work.
	*/
		/* Remove bad characters */
		string = string.replace(fromCharCode(178), "sup2"); /* superscript 2 */
		string = string.replace(fromCharCode(179), "sup3"); /* superscript 3 UTF-16 (decimal) */
		string = string.replace(fromCharCode(0xFE63) + fromCharCode(185), "sup-1"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string = string.replace(fromCharCode(0xFE63) + fromCharCode(178), "sup-2"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string = string.replace(fromCharCode(181)+"m", "um"); /* micron units */
		string = string.replace(getInfo("micrometer.abbreviation"), "um"); /* micron units */
		string = string.replace(fromCharCode(197), "Angstrom"); /* Ångström unit symbol */
		string = string.replace(fromCharCode(0x212B), "Angstrom"); /* the other Ångström unit symbol */
		string = string.replace(fromCharCode(0x2009) + fromCharCode(0x00B0), "deg"); /* replace thin spaces degrees combination */
		string = string.replace(fromCharCode(0x2009), "_"); /* Replace thin spaces  */
		string = string.replace("%", "pc"); /* % causes issues with html listing */
		string = string.replace(" ", "_"); /* Replace spaces - these can be a problem with image combination */
		/* Remove duplicate strings */
		unwantedDupes = newArray("8bit","8-bit","lzw");
		for (i=0; i<lengthOf(unwantedDupes); i++){
			iLast = lastIndexOf(string,unwantedDupes[i]);
			iFirst = indexOf(string,unwantedDupes[i]);
			if (iFirst!=iLast) {
				string = string.substring(0,iFirst) + string.substring(iFirst + lengthOf(unwantedDupes[i]));
				i=-1; /* check again */
			}
		}
		unwantedDbls = newArray("_-","-_","__","--","\\+\\+");
		for (i=0; i<lengthOf(unwantedDbls); i++){
			iFirst = indexOf(string,unwantedDbls[i]);
			if (iFirst>=0) {
				string = string.substring(0,iFirst) + string.substring(string,iFirst + lengthOf(unwantedDbls[i])/2);
				i=-1; /* check again */
			}
		}
		string = string.replace("_\\+", "\\+"); /* Clean up autofilenames */
		/* cleanup suffixes */
		unwantedSuffixes = newArray(" ","_","-","\\+"); /* things you don't wasn't to end a filename with */
		extStart = lastIndexOf(string,".");
		sL = lengthOf(string);
		if (sL-extStart<=4 && extStart>0) extIncl = true;
		else extIncl = false;
		if (extIncl){
			preString = substring(string,0,extStart);
			extString = substring(string,extStart);
		}
		else {
			preString = string;
			extString = "";
		}
		for (i=0; i<lengthOf(unwantedSuffixes); i++){
			sL = lengthOf(preString);
			if (endsWith(preString,unwantedSuffixes[i])) {
				preString = substring(preString,0,sL-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
				i=-1; /* check one more time */
			}
		}
		if (!endsWith(preString,"_lzw") && !endsWith(preString,"_lzw.")) preString = replace(preString, "_lzw", ""); /* Only want to keep this if it is at the end */
		string = preString + extString;
		/* End of suffix cleanup */
		return string;
	}