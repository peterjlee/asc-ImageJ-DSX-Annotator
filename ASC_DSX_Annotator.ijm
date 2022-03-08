/* 
	This macro adds multiple operating parameters extracted from the header of Olympus DSX images.
	Additional parameters are calculated using this data.
	It also automatically embeds the distance calibration in microns if there is no calibration present (or it is in inches).
	v220301: 1st working version
	v220304: Added option to put annotation bar under image SEM-style.
	v220307: Saved preferences added.
 */
macro "Add Multiple Lines of Metadata to DSX Image" {
	macroL = "DSX_Annotator_v220307.ijm";
	imageTitle = getTitle();
	if (!endsWith(toLowerCase(imageTitle), '.dsx'))
		showMessageWithCancel("Title does not end with \"DSX\"", "A DSX image is required, do you want to continue?" + t + " ?");
	// Checks to see if a Ramp legend rather than the image has been selected by accident
	if (matches(imageTitle, ".*Ramp.*")==1) showMessageWithCancel("Title contains \"Ramp\"", "Do you want to label" + t + " ?");
	/* Settings preferences set up */
	userPath = getInfo("user.dir");
	prefsDelimiter = "|";
	prefsNameKey = "ascDSXAnnotatorPrefs.";
	prefsParameters = call("ij.Prefs.get", prefsNameKey+"lastParameters", "None");
	if (prefsParameters!="None") defaultSettings = split(prefsParameters,prefsDelimiter);
	else defaultSettings = newArray("ObservationMethod","ImageType","ImageSizePix","ImageSizeMicrons","ObjectiveLensType","ObjectiveLensMagnification","ZoomMagnification");
	/* End preferences recall */
	settingsDSX = newArray("ObservationMethod","ImageType","ObjectiveLensMagnification","ImageHeight","ImageWidth","ImageDataPerPixelX","ImageDataPerPixelY","ImageDataPerPixelZ","ObjectiveLensType","ZoomMagnification","DigitalZoomMagnification","OpiticalZoomMagnification","ActualMagnificationFor1xZoom","FileVersion","ImageFlip","ImageRotation","ImageRotationAngle","AE","AELock","AEMode","AETargetValue","Binning","BinningLevel","ShadingCorrection","ImageAspectRatio","NoiseReduction","NoiseReductionLevel","BlurCorrection","BlurCorrectionValue","ContrastMode","SharpnessMode","FieldCurvatureCorrection","MicroscopeControllerVersion","StagePositionX","StagePositionY","ImagingAS","BFLight","BFLightBrightnessLevel","RingLightBlock","DFLightBlock","DFLightAngle","DFLightMode","BackLight","BackLightBrightnessLevel","DICShearingLevel","AnalyzerShearingLevel","PBF","CameraName","BlueGainLevel","BlueOffsetLevel","GammaCorrectionLevel","GreenGainLevel","GreenOffsetLevel","RedGainLevel","RedOffsetLevel");
	settingsN = lengthOf(settingsDSX);
	/* Note there is a typo in the Olympus section name: ObsevationSettingInfo[sic] so this may be corrected in the future */
	settingsDSXTitles = newArray("Observation Method","Image Type","Objective Lens Magnification","Image Height \(pixels\)","Image Width \(pixels\)","Pixel Width  \(pm\)","Pixel Height \(pm\)","Pixel Depth \(pixels\)","Objective Lens Type","Zoom Magnification","Digital Zoom Magnification","Optical Zoom Magnification","Actual Magnification For 1x Zoom","File Version","Image Flip","Image Rotation","Image Rotation Angle","AE","AE Lock","AE Mode","AE Target Value","Binning ","Binning Level","Shading Correction","Image Aspect Ratio","Noise Reduction","Noise Reduction Level","Blur Correction","Blur Correction Value","Contrast Mode","Sharpness Mode","Field Curvature Correction","Microscope Controller Version","Stage Position X","Stage Position Y","Imaging AS","BF Light","BF Light Brightness Level","Ring Light Block","DF Light Block","DF Light Angle","DF Light Mode","Back Light","Back Light BrightnessLevel","DIC ShearingLevel","Analyzer Shearing Level","PBF","Camera Name","Blue Gain Level","Blue Offset Level","Gamma Correction Level","Green Gain Level","Green Offset Level","RedGain Level","Red Offset Level");
	observationData = exifDSXs(settingsDSX);
	for(i=0; i<settingsN; i++){
		if (indexOf(settingsDSXTitles[i],"pm")>=0 || indexOf(settingsDSXTitles[i],"pixels")>=0) observationData[i] = parseInt(observationData[i]);
		else if (indexOf(settingsDSXTitles[i],"Zoom")>=0 || indexOf(settingsDSXTitles[i],"pixels")>=0) observationData[i] = d2s(observationData[i],3);
	}
	/* Generate combination labels */
	iWPx = indexOfArray(settingsDSX,"ImageWidth", -1);
	if (iWPx<0) exit("ImageWidth not found");
	iWPxPm = indexOfArray(settingsDSX,"ImageDataPerPixelX", -1);
	if (iWPxPm<0) exit("ImageDataPerPixelX not found");
	iHPx = indexOfArray(settingsDSX,"ImageHeight", -1);
	if (iHPx<0) exit("ImageHeight not found");
	iHPxPm = indexOfArray(settingsDSX,"ImageDataPerPixelY", -1);		
	if (iHPxPm<0) exit("ImageDataPerPixelY not found");
	pxWidthMicrons = parseInt(observationData[iWPxPm]) * pow(10,-6);
	pxHeightMicrons = parseInt(observationData[iHPxPm]) * pow(10,-6);
	iObjMag = indexOfArray(settingsDSX,"ObjectiveLensMagnification", -1);
	if (iObjMag<0) exit("ObjectiveLensMagnification not found");
	iZoomMag = indexOfArray(settingsDSX,"ZoomMagnification", -1);
	if (iZoomMag<0) exit("ZoomMagnification not found");
	iTrueObjZoomF =  indexOfArray(settingsDSX,"ActualMagnificationFor1xZoom", -1);
	if (iZoomMag<0) exit("ActualMagnificationFor1xZoom not found");
	actualObjxZoomMag = d2s(parseFloat(observationData[iObjMag]) * parseFloat(observationData[iZoomMag]) * parseFloat(observationData[iTrueObjZoomF]),4);
	actualObjxZoomMagTitle = "Actual Objective " + fromCharCode(0x00D7) + " Zoom Magnification";
	/* Take the opportunity to embed the scale if it has not been done yet */
	getPixelSize(unit, pixelWidth, pixelHeight);
	if (pixelWidth!=pixelHeight || pixelWidth==1 || unit=="" || unit=="inches" || unit=="pixels"){
		distPerPixel = (pxWidthMicrons + pxHeightMicrons)/2;
		run("Set Scale...", "distance=1 known=&distPerPixel pixel=1 unit=um");
	}
	/* End of scale adding */
	iDIntensityPm = indexOfArray(settingsDSX,"ImageDataPerPixelZ",-1);
	if (iDIntensityPm<0) exit("ImageDataPerPixelZ not found");
	depthCal = parseFloat(observationData[iDIntensityPm]);
	if (depthCal>=1){ 
		depthCalMicrons = depthCal * pow(10,-6);
		fullDepthRangeMicrons = d2s(256 * 256 * depthCalMicrons,3); /* depth map is 16-bit */
	}
	else {
		depthCalMicrons = "No Extended Depth";
		fullDepthRangeMicrons = "No Extended Depth";
	}	
	depthCalMicronsTitle = "Height Map calibration \(" + getInfo("micrometer.abbreviation") + "\/intensity Level\)";
	fullDepthRangeMicronsTitle = "Full 16-bit Height Map Range \(" + getInfo("micrometer.abbreviation") + "\)";
	imageWPx = observationData[iWPx];
	imageWMicrons = parseInt(imageWPx) * pxWidthMicrons;
	imageHPx = observationData[iHPx];
	imageHMicrons = parseInt(imageHPx) * pxHeightMicrons;
	imageSizePix = d2s(imageWPx,0) + " " + fromCharCode(0x00D7) + " " + d2s(imageHPx,0);
	imageSizePixTitle = "Image size \(pixels\)";
	imageSizeMicrons = d2s(imageWMicrons,1) + " " + fromCharCode(0x00D7) + " " + d2s(imageHMicrons,1);
	imageSizeMicronsTitle = "Image size \(" + getInfo("micrometer.abbreviation") + "\)";
	/* End of combination settings */
	observationData = Array.concat(imageTitle,imageSizePix,imageSizeMicrons,actualObjxZoomMag,depthCalMicrons,fullDepthRangeMicrons,observationData);
	imageTitleTitle = "Image Title";
	settingsDSXTitles = Array.concat(imageTitleTitle,imageSizePixTitle,imageSizeMicronsTitle,actualObjxZoomMagTitle,depthCalMicronsTitle,fullDepthRangeMicronsTitle,settingsDSXTitles);

	/* Update settingsDSX array to match above to help call out default settings */
	
	settingsDSX = Array.concat("imageTitle","ImageSizePix","ImageSizeMicrons","actualObjxZoomMag","DepthCalMicrons","FullDepthRangeMicrons",settingsDSX);
	dataN = lengthOf(observationData);
	titlesN = lengthOf(settingsDSXTitles);
	if (dataN!=titlesN) exit("Number of titles \("+titlesN+"\) does not equal number of settings \("+settingsN+"\)");
	observationLabels = newArray(dataN);
	for(i=0; i<dataN; i++) observationLabels[i] = settingsDSXTitles[i] + ": " + observationData[i];
	// for(i=0; i<dataN; i++) print(observationLabels[i]);
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
	imageWidth = getWidth();
	imageHeight = getHeight();
	imageDims = imageHeight + imageWidth;
	imageDepth = bitDepth();
	id = getImageID();
	fontSize = round(imageDims/140); /* default font size is small for this variant */
	if (fontSize < 10) fontSize = 10; /* set minimum default font size as 12 */
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
	selOffsetX = round(1 + imageWidth/150); /* default offset of label from edge */
	selOffsetY = round(1 + imageHeight/150); /* default offset of label from edge */
	/* Then Dialog . . . */
	Dialog.create("Basic Label Options: " + macroL);
		Dialog.addString("Optional list title \((leave blank for none\)","",50);
		Dialog.addMessage("Labels: ^2 & um etc. replaced by " + fromCharCode(178) + " & " + fromCharCode(181) + "m etc. If the units are in the parameter label, within \(...\) i.e. \(unit\) they will override this selection:");
		Dialog.addCheckboxGroup(1+dataN/3,3,observationLabels,defaultLabelChecks);
		Dialog.addRadioButtonGroup("Also output to log window?", newArray("No","Just selected","All parameters"),1,3,"Just selected");
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
		Dialog.addNumber("Font size & color:", fontSize, 0, 3,"");
		if (imageDepth==24)
			colorChoice = newArray("white", "black", "off-white", "off-black", "light_gray", "gray", "dark_gray", "red", "cyan", "pink", "green", "blue", "yellow", "orange", "garnet", "gold", "aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "blue_honolulu", "gray_modern", "green_dark_modern", "green_modern", "orange_modern", "pink_modern", "purple_modern", "jazzberry_jam", "red_n_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern", "radical_red", "wild_watermelon", "outrageous_orange", "atomic_tangerine", "neon_carrot", "sunglow", "laser_lemon", "electric_lime", "screamin'_green", "magic_mint", "blizzard_blue", "shocking_pink", "razzle_dazzle_rose", "hot_magenta");
		else colorChoice = newArray("white", "black", "light_gray", "gray", "dark_gray");
		Dialog.setInsets(-30, 60, 0);
		Dialog.addChoice("Text color:", colorChoice, colorChoice[0]);
		fontStyleChoice = newArray("bold", "bold antialiased", "italic", "italic antialiased", "bold italic", "bold italic antialiased", "unstyled");
		Dialog.addChoice("Font style:", fontStyleChoice, fontStyleChoice[1]);
		fontNameChoice = getFontChoiceList();
		Dialog.addChoice("Font name:", fontNameChoice, fontNameChoice[0]);
		Dialog.addChoice("Outline color:", colorChoice, colorChoice[1]);
		Dialog.addCheckbox("Do not use outlines and shadows \(if 'Under' is selected for location, no outlines or shadows will be used\)",false);

		Dialog.addCheckbox("Tweak the Formatting?",false);
/*	*/
	Dialog.show();
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
		textLocChoice = Dialog.getChoice();
		underClear = Dialog.getNumber();
		if (selectionExists==1) {
			selEX =  Dialog.getNumber();
			selEY =  Dialog.getNumber();
			selEWidth =  Dialog.getNumber();
			selEHeight =  Dialog.getNumber();
		}
		fontSize =  Dialog.getNumber();
		selColor = Dialog.getChoice();
		fontStyle = Dialog.getChoice();
		fontName = Dialog.getChoice();
		outlineColor = Dialog.getChoice();
		notFancy = Dialog.getCheckbox(); 
		tweakFormat = Dialog.getCheckbox();
/*	*/
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
			Dialog.addChoice("Outline (background) color:", colorChoice, colorChoice[1]);
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
				if (lineStart + selOffsetX + labelLength + 4 < ((100-underClear)*imageWidth/100)){
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
		selEX = imageWidth - longestStringWidth - selOffsetX;
		selEY = selOffsetY;
	} else if (textLocChoice == "Center") {
		selEX = round((imageWidth - longestStringWidth)/2);
		selEY = round((imageHeight - linesSpace)/2);
	} else if (textLocChoice == "Bottom Left") {
		selEX = selOffsetX;
		selEY = imageHeight - (selOffsetY + linesSpace);
	} else if (textLocChoice == "Under") {
		selEX = selOffsetX;
		selEY = imageHeight + selOffsetY +  fontSize + lineSpacing;	
	} else if (textLocChoice == "Bottom Right") {
		selEX = imageWidth - longestStringWidth - selOffsetX;
		selEY = imageHeight - (selOffsetY + linesSpace);
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
	if ((endX+selOffsetX)>imageWidth) selEX = imageWidth - longestStringWidth - selOffsetX;
	textLabelX = selEX;
	textLabelY = selEY;
	setBatchMode(true);
	roiManager("show none");
	run("Duplicate...", imageTitle + "+text");
	labeledImage = getTitle();
	setFont(fontName,fontSize, fontStyle);
	if(textLocChoice=="Under"){
		newHeight = imageHeight + (2 * selOffsetY + (fontSize + lineSpacing) * (underLabelsN + 0.5));
		selColors = getColorArrayFromColorName(selColor);
		Array.getStatistics(selColors,null,null,meanSelColInt,null);
		if (meanSelColInt<128) run("Colors...", "background=white");
		else run("Colors...", "background=black");
		run("Canvas Size...", "width=[imageWidth] height=[newHeight] position=Top-Center");
		run ("Colors...", "background=white");
	}
	if(!notFancy) {
		newImage("label_mask", "8-bit black", imageWidth, imageHeight, 1);
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
		colorHex = getHexColorFromRGBArray(selColor);
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
			v220307 += restored for else line*/
		for (i=0; i<array.length; i++){
			if (i==0) string = "" + array[0];
			else  string += delimiter + array[i];
		}
		return string;
	}
	function cleanLabel(string) {
		/*  ImageJ macro default file encoding (ANSI or UTF-8) varies with platform so non-ASCII characters may vary: hence the need to always use fromCharCode instead of special characters.
		v180611 added "degreeC"
		v200604	fromCharCode(0x207B) removed as superscript hyphen not working reliably	*/
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
		string= replace(string, "\\b[aA]ngstrom\\b", fromCharCode(197)); /* Ångström unit symbol */
		string= replace(string, "  ", " "); /* Replace double spaces with single spaces */
		string= replace(string, "_", " "); /* Replace underlines with space as thin spaces (fromCharCode(0x2009)) not working reliably  */
		string= replace(string, "px", "pixels"); /* Expand pixel abbreviation */
		string= replace(string, "degreeC", fromCharCode(0x00B0) + "C"); /* Degree symbol for dialog boxes */
		string = replace(string, " " + fromCharCode(0x00B0), fromCharCode(0x2009) + fromCharCode(0x00B0)); /* Replace normal space before degree symbol with thin space */
		string= replace(string, " °", fromCharCode(0x2009) + fromCharCode(0x00B0)); /* Replace normal space before degree symbol with thin space */
		string= replace(string, "sigma", fromCharCode(0x03C3)); /* sigma for tight spaces */
		string= replace(string, "±", fromCharCode(0x00B1)); /* plus or minus */
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
		newImage("inner_shadow", "8-bit white", imageWidth, imageHeight, 1);
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
		newImage("shadow", "8-bit black", imageWidth, imageHeight, 1);
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
	function exifDSXs(parameters) {
	/* Returns requested parameter from DSX EXIF header	
	ObsevationSettingInfo Only
	v220228 1st working version
	v220301 Index search strings now includes both open and close "<" to avoid ambiguity (ImageType). Now checks to see of "obsevation" typo has been fixed.
	*/
	if (is("Batch Mode")){
		batchOn = true;
	}
	else {
		batchOn = false;
		setBatchMode(true);
	}
	if (nImages==0) return "Error: no images open";
	selectImage(getImageID);
	title = getTitle();
	if (!endsWith(toLowerCase(title), '.dsx'))
		exit("The active image is not a DSX");
	run("Exif Data...");
	list = getList("window.titles");
	exifListed = false;
	for (i=0; i<list.length; i++){
		if (startsWith(list[i],"EXIF Metadata for ")){
			exifWindow = list[i];
			if (exifListed){
				print("Multiple EXIF windows are open, the last one will be used and then closed");
				exifListed = true;
			}
		}
	}
	selectWindow(exifWindow);
	fullEXIF = getInfo();
	metaDatas = newArray();
	observationSettings = "ObjectiveLensID ObjectiveLensType ObjectiveLensMagnification Telecentric ZoomMagnification OpiticalZoomMagnification DigitalZoomMagnification ObservationMethod TiltingFrameAngle StageAngle ApertureStop ApertureStopLevel ImagingAS FieldStop FieldStopLevel BFLight BFLightBrightnessLevel FiberLight FiberLightBrightnessLevel RingLightBlock DFLightBlock DFLightBrightnessLevel";
	if(indexOf(fullEXIF,"Obsevation")<0) exit("Obs'ev'ation typo has been fixed; please update exifDSXs function");
	obsEXIF = substring(fullEXIF,indexOf(fullEXIF,"<ObsevationSettingInfo>"));
	for(i=0; i<lengthOf(parameters); i++){
		parameter = parameters[i];
		if(indexOf(observationSettings,parameter)<0){
			index0 = indexOf(fullEXIF, "<" + parameter + ">") + lengthOf(parameter) + 2;
			index1 = indexOf(fullEXIF, "</" + parameter + ">")-1;
			if (index0==-1 || index0==-1) 
				metaDatas[i] = "Error: "+parameter+" for \"" + title + "\"";
			else
				metaDatas[i] = substring(fullEXIF, index0, index1+1);
		}
		else {
			index0 = indexOf(obsEXIF, "<" + parameter + ">") + lengthOf(parameter) + 2;
			index1 = indexOf(obsEXIF, "</" + parameter + ">")-1;
			if (index0==-1 || index0==-1) 
				metaDatas[i] = "Error: "+parameter+" for \"" + title + "\"";
			else
				metaDatas[i] = substring(obsEXIF, index0, index1 + 1);			
		}
	}
	close(exifWindow);
	if(!batchOn)	setBatchMode("exit and display");
	// print("Array.print\(metaDatas\)", "length of parameters:", lengthOf(parameters),"length of metaDatas:",lengthOf(metaDatas));
	// Array.print(metaDatas);
	return metaDatas;
	}
	/*	Color Functions	*/
	
	function getColorArrayFromColorName(colorName) {
		/* v180828 added Fluorescent Colors
		   v181017-8 added off-white and off-black for use in gif transparency and also added safe exit if no color match found
		   v191211 added Cyan
		   v211022 all names lower-case, all spaces to underscores v220225 Added more hash value comments as a reference
		*/
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
		else if (colorName == "pink") cA = newArray(255, 192, 203);
		else if (colorName == "green") cA = newArray(0,255,0); /* #00FF00 AKA Lime green */
		else if (colorName == "blue") cA = newArray(0,0,255);
		else if (colorName == "yellow") cA = newArray(255,255,0);
		else if (colorName == "orange") cA = newArray(255, 165, 0);
		else if (colorName == "cyan") cA = newArray(0, 255, 255);
		else if (colorName == "garnet") cA = newArray(120,47,64);
		else if (colorName == "gold") cA = newArray(206,184,136);
		else if (colorName == "aqua_modern") cA = newArray(75,172,198); /* #4bacc6 AKA "Viking" aqua */
		else if (colorName == "blue_accent_modern") cA = newArray(79,129,189); /* #4f81bd */
		else if (colorName == "blue_dark_modern") cA = newArray(31,73,125); /* #1F497D */
		else if (colorName == "blue_modern") cA = newArray(58,93,174); /* #3a5dae */
		else if (colorName == "blue_honolulu") cA = newArray(0,118,182); /* Honolulu Blue #30076B6 */
		else if (colorName == "gray_modern") cA = newArray(83,86,90); /* bright gray #53565A */
		else if (colorName == "green_dark_modern") cA = newArray(121,133,65); /* Wasabi #798541 */
		else if (colorName == "green_modern") cA = newArray(155,187,89); /* #9bbb59 AKA "Chelsea Cucumber" */
		else if (colorName == "green_modern_accent") cA = newArray(214,228,187); /* #D6E4BB AKA "Gin" */
		else if (colorName == "green_spring_accent") cA = newArray(0,255,102); /* #00FF66 AKA "Spring Green" */
		else if (colorName == "orange_modern") cA = newArray(247,150,70); /* #f79646 tan hide, light orange */
		else if (colorName == "pink_modern") cA = newArray(255,105,180); /* hot pink #ff69b4 */
		else if (colorName == "purple_modern") cA = newArray(128,100,162); /* blue-magenta, purple paradise #8064A2 */
		else if (colorName == "jazzberry_jam") cA = newArray(165,11,94);
		else if (colorName == "red_n_modern") cA = newArray(227,24,55);
		else if (colorName == "red_modern") cA = newArray(192,80,77);
		else if (colorName == "tan_modern") cA = newArray(238,236,225);
		else if (colorName == "violet_modern") cA = newArray(76,65,132);
		else if (colorName == "yellow_modern") cA = newArray(247,238,69);
		/* Fluorescent Colors https://www.w3schools.com/colors/colors_crayola.asp */
		else if (colorName == "radical_red") cA = newArray(255,53,94);			/* #FF355E */
		else if (colorName == "wild_watermelon") cA = newArray(253,91,120);		/* #FD5B78 */
		else if (colorName == "outrageous_orange") cA = newArray(255,96,55);	/* #FF6037 */
		else if (colorName == "supernova_orange") cA = newArray(255,191,63);	/* FFBF3F Supernova Neon Orange*/
		else if (colorName == "atomic_tangerine") cA = newArray(255,153,102);	/* #FF9966 */
		else if (colorName == "neon_carrot") cA = newArray(255,153,51);			/* #FF9933 */
		else if (colorName == "sunglow") cA = newArray(255,204,51); 			/* #FFCC33 */
		else if (colorName == "laser_lemon") cA = newArray(255,255,102); 		/* #FFFF66 "Unmellow Yellow" */
		else if (colorName == "electric_lime") cA = newArray(204,255,0); 		/* #CCFF00 */
		else if (colorName == "screamin'_green") cA = newArray(102,255,102); 	/* #66FF66 */
		else if (colorName == "magic_mint") cA = newArray(170,240,209); 		/* #AAF0D1 */
		else if (colorName == "blizzard_blue") cA = newArray(80,191,230); 		/* #50BFE6 Malibu */
		else if (colorName == "dodger_blue") cA = newArray(9,159,255);			/* #099FFF Dodger Neon Blue */
		else if (colorName == "shocking_pink") cA = newArray(255,110,255);		/* #FF6EFF Ultra Pink */
		else if (colorName == "razzle_dazzle_rose") cA = newArray(238,52,210); 	/* #EE34D2 */
		else if (colorName == "hot_magenta") cA = newArray(255,0,204);			/* #FF00CC AKA Purple Pizzazz */
		else restoreExit("No color match to " + colorName);
		return cA;
	}
	function setBackgroundFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setBackgroundColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function getHexColorFromRGBArray(colorNameString) {
		colorArray = getColorArrayFromColorName(colorNameString);
		 r = toHex(colorArray[0]); g = toHex(colorArray[1]); b = toHex(colorArray[2]);
		 hexName= "#" + ""+pad(r) + ""+pad(g) + ""+pad(b);
		 return hexName;
	}
	function pad(n) {
		n= toString(n); if (lengthOf(n)==1) n= "0"+n; return n;
	}
		
	/*	End of Color Functions	*/
	
  	function getFontChoiceList() {
		/*	v180723 first version
			v180828 Changed order of favorites
			v190108 Longer list of favorites
		*/
		systemFonts = getFontList();
		IJFonts = newArray("SansSerif", "Serif", "Monospaced");
		fontNameChoice = Array.concat(IJFonts,systemFonts);
		faveFontList = newArray("Your favorite fonts here", "Open Sans ExtraBold", "Fira Sans ExtraBold", "Noto Sans Black", "Arial Black", "Montserrat Black", "Lato Black", "Roboto Black", "Merriweather Black", "Alegreya Black", "Tahoma Bold", "Calibri Bold", "Helvetica", "SansSerif", "Calibri", "Roboto", "Tahoma", "Times New Roman Bold", "Times Bold", "Serif");
		faveFontListCheck = newArray(faveFontList.length);
		counter = 0;
		for (i=0; i<faveFontList.length; i++) {
			for (j=0; j<fontNameChoice.length; j++) {
				if (faveFontList[i] == fontNameChoice[j]) {
					faveFontListCheck[counter] = faveFontList[i];
					counter +=1;
					j = fontNameChoice.length;
				}
			}
		}
		faveFontListCheck = Array.trim(faveFontListCheck, counter);
		fontNameChoice = Array.concat(faveFontListCheck,fontNameChoice);
		return fontNameChoice;
	}	
	function getSelectionFromMask(selection_Mask){
		batchMode = is("Batch Mode"); /* Store batch status mode before toggling */
		if (!batchMode) setBatchMode(true); /* Toggle batch mode on if previously off */
		tempTitle = getTitle();
		selectWindow(selection_Mask);
		run("Create Selection"); /* Selection inverted perhaps because the mask has an inverted LUT? */
		run("Make Inverse");
		selectWindow(tempTitle);
		run("Restore Selection");
		if (!batchMode) setBatchMode(false); /* Return to original batch mode setting */
	}
	function indexOfArray(array,string, default) {
		/* v190423 Adds "default" parameter (use -1 for backwards compatibility). Returns only first instance of string */
		index = default;
		for (i=0; i<lengthOf(array); i++){
			if (array[i]==string) {
				index = i;
				i = lengthOf(array);
			}
		}
		return index;
	}
	function stripKnownExtensionFromString(string) {
		/*	Note: Do not use on path as it may change the directory names
		v211112: Tries to fix trapped extension before channel listing. Adds xlsx extension.
		*/
		string = "" + string;
		if (lastIndexOf(string, ".")!=-1) {
			knownExt = newArray("dsx", "DSX", "tif", "tiff", "TIF", "TIFF", "png", "PNG", "GIF", "gif", "jpg", "JPG", "jpeg", "JPEG", "jp2", "JP2", "txt", "TXT", "csv", "CSV","xlsx","XLSX","_"," ");
			chanLabels = newArray("\(red\)","\(green\)","\(blue\)");
			for (i=0; i<knownExt.length; i++) {
				for (j=0; j<3; j++){
					ichanLabels = lastIndexOf(string, chanLabels[j]);
					index = lastIndexOf(string, "." + knownExt[i]);
					if (ichanLabels>index && index>0) string = "" + substring(string, 0, index) + "_" + chanLabels[j];
				}
				index = lastIndexOf(string, "." + knownExt[i]);
				if (index>=(lengthOf(string)-(lengthOf(knownExt[i])+1)) && index>0) string = "" + substring(string, 0, index);
			}
		}
		unwantedSuffixes = newArray("_lzw"," ","  ", "__","--","_","-");
		for (i=0; i<lengthOf(unwantedSuffixes); i++){
			sL = lengthOf(string);
			if (endsWith(string,unwantedSuffixes[i])) string = substring(string,0,sL-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
		}
		return string;
	}
	function unCleanLabel(string) {
	/* v161104 This function replaces special characters with standard characters for file system compatible filenames.
	+ 041117b to remove spaces as well.
	+ v220126 added getInfo("micrometer.abbreviation").
	+ v220128 add loops that allow removal of multiple duplication.
	+ v220131 fixed so that suffix cleanup works even if extensions are included.
	*/
		/* Remove bad characters */
		string= replace(string, fromCharCode(178), "\\^2"); /* superscript 2 */
		string= replace(string, fromCharCode(179), "\\^3"); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, fromCharCode(0xFE63) + fromCharCode(185), "\\^-1"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string= replace(string, fromCharCode(0xFE63) + fromCharCode(178), "\\^-2"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string= replace(string, fromCharCode(181), "u"); /* micron units */
		string= replace(string, getInfo("micrometer.abbreviation"), "um"); /* micron units */
		string= replace(string, fromCharCode(197), "Angstrom"); /* Ångström unit symbol */
		string= replace(string, fromCharCode(0x2009) + fromCharCode(0x00B0), "deg"); /* replace thin spaces degrees combination */
		string= replace(string, fromCharCode(0x2009), "_"); /* Replace thin spaces  */
		string= replace(string, "%", "pc"); /* % causes issues with html listing */
		string= replace(string, " ", "_"); /* Replace spaces - these can be a problem with image combination */
		/* Remove duplicate strings */
		unwantedDupes = newArray("8bit","lzw");
		for (i=0; i<lengthOf(unwantedDupes); i++){
			iLast = lastIndexOf(string,unwantedDupes[i]);
			iFirst = indexOf(string,unwantedDupes[i]);
			if (iFirst!=iLast) {
				string = substring(string,0,iFirst) + substring(string,iFirst + lengthOf(unwantedDupes[i]));
				i=-1; /* check again */
			}
		}
		unwantedDbls = newArray("_-","-_","__","--","\\+\\+");
		for (i=0; i<lengthOf(unwantedDbls); i++){
			iFirst = indexOf(string,unwantedDbls[i]);
			if (iFirst>=0) {
				string = substring(string,0,iFirst) + substring(string,iFirst + lengthOf(unwantedDbls[i])/2);
				i=-1; /* check again */
			}
		}
		string= replace(string, "_\\+", "\\+"); /* Clean up autofilenames */
		/* cleanup suffixes */
		unwantedSuffixes = newArray(" ","_","-","\\+"); /* things you don't wasn't to end a filename with */
		extStart = lastIndexOf(string,".");
		sL = lengthOf(string);
		if (sL-extStart<=4) extIncl = true;
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
}