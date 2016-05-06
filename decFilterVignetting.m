function vignetteMat=decFilterVignetting(refImage,binaryimage,ROI_coords)

dimROI=ROI_coords(end,:);
tmpIm=refImage(dimROI(2):dimROI(4),dimROI(1):dimROI(3));
tmpBw=binaryimage(dimROI(2):dimROI(4),dimROI(1):dimROI(3));
dimROI=tmpIm.*uint8(tmpBw);
dimROI=double(dimROI);
dimROI(dimROI==0)=NaN;
lumOffset=max(max(dimROI));
vignetteMat=refImage-lumOffset;