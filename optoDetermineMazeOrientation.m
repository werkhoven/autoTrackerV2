function [mazeOri]=optoDetermineMazeOrientation(binaryimage,ROI_coords)

%% Horizontally bisect the ROI in top and bottom half and sum across the rows for orienation

%(upside down Y = 0, right-side up = 1)

nROIs=size(ROI_coords,1);
mazeOri=zeros(nROIs,1);


for i=1:nROIs
    tempImage=binaryimage(ROI_coords(i,2):ROI_coords(i,4),ROI_coords(i,1):ROI_coords(i,3));
    yCenter=round(size(tempImage,1)/2);
    x = size(tempImage,1);
    top=sum(sum(tempImage(1:yCenter,:)));
    bot=sum(sum(tempImage(yCenter:x,:)));
    
    if top>bot
        mazeOri(i)=1; 
    elseif bot>top
        mazeOri(i)=0; 
    end
end
        



