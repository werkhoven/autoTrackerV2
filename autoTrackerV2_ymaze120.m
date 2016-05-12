
%% Define parameters - adjust parameters here to fix tracking and ROI segmentation errors

% Experimental parameters
exp_duration=handles.expDuration*60;           % Duration of the experiment in minutes
referenceStackSize=handles.refStack;        % Number of images to keep in rolling reference
referenceFreq=handles.refTime;              % Seconds between reference images
referenceTime = 600;                        % Seconds over which intial reference images are taken

% Tracking parameters
imageThresh=get(handles.slider2,'value');    % Difference image threshold for detecting centroids
speedThresh=35;                              % Maximum allow pixel speed (px/s);

% ROI detection parameters
ROI_thresh=get(handles.slider1,'value');    % Binary image threshold from zero (black) to one (white) for segmentation  
sigma=0.47;                                 % Sigma expressed as a fraction of the image height
kernelWeight=0.34;                          % Scalar weighting of kernel when applied to the image

%% Save labels and create placeholder files for data

t = datestr(clock,'mm-dd-yyyy_');
labels = cell2table(labelMaker(handles.labels),'VariableNames',{'Strain' 'Sex' 'Treatment'});
strain=labels{1,1}{:};
treatment=labels{1,3}{:};
labelID = [handles.fpath '\' t '_labels.dat'];     % File ID for label data
writetable(labels, labelID);                       % Save label table

% Create placeholder files
cenID = [handles.fpath '\' t strain '_' treatment '_Centroid.dat'];            % File ID for centroid data
oriID = [handles.fpath '\' t strain '_' treatment '_Orientation.dat'];         % File ID for orientation angle
turnID = [handles.fpath '\' t strain '_' treatment '_RightTurns.dat'];         % File ID for turn data
 
dlmwrite(cenID, []);                          % create placeholder ASCII file
dlmwrite(oriID, []);                          % create placeholder ASCII file
dlmwrite(turnID, []);                         % create placeholder ASCII file

%% Setup the camera and video object

% Reset any open camera objects
imaqreset             
pause(0.5); 
% Camera mode set to 8-bit with 664x524 resolution
vid = initializeCamera('pointgrey',1,'F7_BayerRG8_664x524_Mode1');
pause(0.5);
        
%% Grab image for ROI detection and segment out ROIs
stop=get(handles.togglebutton10,'value');

while stop~=1;
tic

% Check to see if accept reference has been pushed GUI
stop=get(handles.togglebutton10,'value');

% Take single frame
imagedata=peekdata(vid,1);
% Extract red channel
ROI_image=imagedata(:,:,1);

% Update threshold value
ROI_thresh=get(handles.slider1,'value');

% Build a subtraction matrix to smooth vignetting prior to ROI extraction
% Will be replaced by decFilterVignetting once ROIs are detected
gaussianKernel=buildGaussianKernel(size(ROI_image,2),size(ROI_image,1),sigma,kernelWeight);
ROI_image=(uint8(double(ROI_image).*gaussianKernel));

% Extract ROIs from thresholded image
[ROI_bounds,ROI_coords,ROI_widths,ROI_heights,binaryimage] = detect_ROIs(ROI_image,ROI_thresh);

% Create orientation vector for mazes (upside down Y = 0, right-side up = 1)
mazeOri=optoDetermineMazeOrientation(binaryimage,ROI_coords);
mazeOri=boolean(mazeOri);

% Calculate coords of ROI centers
[xCenters,yCenters]=optoROIcenters(binaryimage,ROI_coords);
centers=[xCenters,yCenters];

% Define a permutation vector to sort ROIs from top-right to bottom left
[ROI_coords,mazeOri,ROI_bounds,centers]=optoSortROIs(ROI_coords,mazeOri,centers,ROI_bounds);

% Display number of ROIs detected
set(handles.edit7,'String',num2str(size(ROI_bounds,1)));

% Update display with ROI bounding boxes and sorted numbers
if get(handles.togglebutton7,'value')==1
    imshow(binaryimage);
    hold on
    for i = 1:size(ROI_bounds,1)
        rectangle('Position',ROI_bounds(i,:),'EdgeColor','r')
        if mazeOri(i)
            text(centers(i,1)-5,centers(i,2),int2str(i),'Color','m')
        else
            text(centers(i,1)-5,centers(i,2),int2str(i),'Color','b')
        end
    end
    hold off
    drawnow
end

% Update frame rate display    
set(handles.edit8,'String',num2str(round(1/toc)));
end

% Reset the accept threshold button
set(handles.togglebutton10,'value',0);

%% Automatically average out flies from reference image

refImage=imagedata(:,:,1);                              % Assign reference image
lastCentroid=centers;                                   % Create placeholder for most recent non-NaN centroids
referenceCentroids=zeros(size(ROI_coords,1),2,10);      % Create placeholder for cen. coords when references are taken
propFields={'Centroid';'Orientation';'Area'};           % Define fields for regionprops
nRefs=zeros(size(ROI_coords,1),1);                      % Reference number placeholder
numbers=1:size(ROI_coords,1);                           % Numbers to display while tracking

% Create placeholder for time stamps of each flies last centroid update
% Used to calculate speed of each fly
centStamp=zeros(size(ROI_coords,1),1);                  

% Define a subtraction matrix to correct for vignetting
vignetteMat=decFilterVignetting(refImage,binaryimage,ROI_coords);

% Set maximum allowable distance to center of ROI as the long axis of the
% ROI + some error
widths=(ROI_bounds(:,3));
heights=(ROI_bounds(:,4));
w=median(widths);
h=median(heights);
% Set max distance as the long axis of each ROI bounding box divided by 2
distanceThresh=sqrt(w^2+h^2)/2*0.95;    

% Calculate threshold for distance to end of maze arms for turn scoring
mazeLengths=mean([widths heights],2);
armThresh=mazeLengths.*0.2;

% Time stamp placeholders
tElapsed=0;
tic
previous_tStamp=toc;
current_tStamp=0;

% Collect reference until timeout OR "accept reference" GUI press
while toc<referenceTime&&get(handles.togglebutton11,'value')~=1
    
    % Update image threshold value from GUI
    imageThresh=get(handles.slider2,'value');
    
    % Update tStamps
    current_tStamp=toc;
    set(handles.edit8,'String',num2str(round(1/(current_tStamp-previous_tStamp))));
    tElapsed=tElapsed+current_tStamp-previous_tStamp;
    previous_tStamp=current_tStamp;
    
        % Report time remaining to reference timeout to GUI
        timeRemaining = round(referenceTime - toc);
        if timeRemaining < 60; 
            set(handles.edit6, 'String', ['00:00:' sprintf('%0.2d',timeRemaining)]);
            set(handles.edit6, 'BackgroundColor', [1 0.4 0.4]);
        elseif (3600 > timeRemaining) && (timeRemaining > 60);
            min = floor(timeRemaining/60);
            sec = rem(timeRemaining, 60);
            set(handles.edit6, 'String', ['00:' sprintf('%0.2d',min) ':' sprintf('%0.2d',sec)]);
            set(handles.edit6, 'BackgroundColor', [1 1 1]);
        elseif timeRemaining > 3600;
            hr = floor(timeRemaining/3600);
            min = floor(rem(timeRemaining, 3600)/60);
            sec = timeRemaining - hr*3600 - min*60;
            set(handles.edit6, 'String', [sprintf('%0.2d', hr) ':' sprintf('%0.2d',min) ':' sprintf('%0.2d',sec)]);
            set(handles.edit6, 'BackgroundColor', [1 1 1]);
        end
        
        % Take difference image
        imagedata=peekdata(vid,1);
        imagedata=imagedata(:,:,1);
        subtractedData=(refImage-vignetteMat)-(imagedata-vignetteMat);

        % Extract regionprops and record centroid for blobs with (4 > area > 120) pixels
        props=regionprops((subtractedData>imageThresh),propFields);
        validCentroids=([props.Area]>4&[props.Area]<120);
        
        % Keep only centroids satisfying size constraints and reshape into
        % ROInumber x 2 array
        cenDat=reshape([props(validCentroids).Centroid],2,length([props(validCentroids).Centroid])/2)';
        oriDat=reshape([props(validCentroids).Orientation],1,length([props(validCentroids).Orientation]))';

        % Match centroids to ROIs by finding nearest ROI center
        [lastCentroid,centStamp,tOriDat]=...
            optoMatchCentroids2ROIs(cenDat,oriDat,centers,speedThresh,distanceThresh,lastCentroid,centStamp,tElapsed);
        % Step through each ROI one-by-one
        for i=1:size(ROI_coords,1)

        % Calculate distance to previous locations where references were taken
        tCen=repmat(lastCentroid(i,:),size(referenceCentroids,3),1);
        d=abs(sqrt(dot((tCen-squeeze(referenceCentroids(i,:,:))'),(squeeze(referenceCentroids(i,:,:))'-tCen),2)));

            % Create a new reference image for the ROI if fly is greater than distance thresh
            % from previous reference locations
            if sum(d<10)==0&&sum(isnan(lastCentroid(i,:)))==0
                nRefs(i)=sum(sum(referenceCentroids(i,:,:)>0));
                referenceCentroids(i,:,mod(nRefs(i)+1,10))=lastCentroid(i,:);
                newRef=imagedata(ROI_coords(i,2):ROI_coords(i,4),ROI_coords(i,1):ROI_coords(i,3));
                oldRef=refImage(ROI_coords(i,2):ROI_coords(i,4),ROI_coords(i,1):ROI_coords(i,3));
                nRefs(i)=sum(sum(referenceCentroids(i,:,:)>0));                                         % Update num Refs
                averagedRef=newRef.*(1/nRefs(i))+oldRef.*(1-(1/nRefs(i)));               % Weight new reference by 1/nRefs
                refImage(ROI_coords(i,2):ROI_coords(i,4),ROI_coords(i,1):ROI_coords(i,3))=averagedRef;
            end
        end
        
       % Check "Display ON" toggle button from GUI 
       if get(handles.togglebutton7,'value')==1
           % Update the plot with new reference
           imshow(subtractedData>imageThresh);

           % Draw last known centroid for each ROI and update ref. number indicator
           hold on
           for i=1:size(ROI_coords,1)
               color=[(1/nRefs(i)) 0 (1-1/nRefs(i))];
               color(color>1)=1;
               color(color<0)=0;
               plot(ROI_coords(i,1),ROI_coords(i,2),'o','Linew',3,'Color',color);      
               text(ROI_coords(i,1),ROI_coords(i,2)+15,int2str(numbers(i)),'Color','m')
               text(lastCentroid(i,1),lastCentroid(i,2),int2str(numbers(i)),'Color','R')
           end
       hold off
       drawnow
       end  
    
    % Pause script on GUI pause button press 
    if get(handles.togglebutton9, 'Value') == 1;
        waitfor(handles.togglebutton9, 'Value', 0)
    end

end

% Update vignette offset matrix with better reference
vignetteMat=decFilterVignetting(refImage,binaryimage,ROI_coords);

% Reset accept reference button
set(handles.togglebutton11,'value',0);

%% Collect noise statistics and display sample tracking before initiating experiment


ct=1;                               % Frame counter
pixDistSize=100;                    % Num values to record in p
pixelDist=NaN(pixDistSize,1);       % Distribution of total number of pixels above image threshold
tElapsed=0;
tic   

while ct<pixDistSize;
        
        % Grab image thresh from GUI slider
        imageThresh=get(handles.slider2,'value');

        % Update time stamps
        current_tStamp=toc;
        tElapsed=tElapsed+current_tStamp-previous_tStamp;
        set(handles.edit8,'String',num2str(round(1/(current_tStamp-previous_tStamp))));
        previous_tStamp=current_tStamp;

            timeRemaining = round(referenceTime - toc);
                
                set(handles.edit10, 'String', num2str(pixDistSize-ct));

               % Get centroids and sort to ROIs
               imagedata=peekdata(vid,1);
               imagedata=imagedata(:,:,1);
               imagedata=(refImage-vignetteMat)-(imagedata-vignetteMat);
               

               % Extract regionprops and record centroid for blobs with (4 > area > 120) pixels
               props=regionprops((imagedata>imageThresh),propFields);
               validCentroids=([props.Area]>4&[props.Area]<120);
               
               % Keep only centroids satisfying size constraints and reshape into
               % ROInumber x 2 array
               cenDat=reshape([props(validCentroids).Centroid],2,length([props(validCentroids).Centroid])/2)';
               oriDat=reshape([props(validCentroids).Orientation],1,length([props(validCentroids).Orientation]))';
               
               % Sort centroids to their respective ROIs
               [lastCentroid,centStamp,tOriDat]=...
                    optoMatchCentroids2ROIs(cenDat,oriDat,centers,speedThresh,distanceThresh,lastCentroid,centStamp,tElapsed);
                
               %Update display if display tracking is ON
               if get(handles.togglebutton7,'Value') == 1;
                   imshow(imagedata>imageThresh);
                   hold on
                   % Mark centroids
                   plot(lastCentroid(:,1),lastCentroid(:,2),'o','Color','r');
               hold off
               drawnow
               end
               
           % Create distribution for num pixels above imageThresh
           % Image statistics used later during acquisition to detect noise
           pixelDist(mod(ct,pixDistSize)+1)=nansum(nansum(imagedata>imageThresh));
           ct=ct+1;
   
   % Pause the script if the pause button is hit
   if get(handles.togglebutton9, 'Value') == 1;
      waitfor(handles.togglebutton9, 'Value', 0)    
   end

end

% Record stdDev and mean without noise
pixStd=nanstd(pixelDist);
pixMean=nanmean(pixelDist);    

%% Calculate coordinates of end of each maze arm

arm_coords=zeros(size(ROI_coords,1),2,6);   % Placeholder
w=ROI_bounds(:,3);                          % width of each ROI
h=ROI_bounds(:,4);                          % height of each ROI
% Offsets to shift arm coords from edge of ROI bounding box
xShift=w.*0.15;                             
yShift=h.*0.15;

% Coords 1-3 are for upside-down Ys
arm_coords(:,:,1)=[ROI_coords(:,1)+xShift ROI_coords(:,4)-yShift];
arm_coords(:,:,2)=[centers(:,1) ROI_coords(:,2)+yShift];
arm_coords(:,:,3)=[ROI_coords(:,3)-xShift ROI_coords(:,4)-yShift];

% Coords 4-6 are for right-side up Ys
arm_coords(:,:,4)=[ROI_coords(:,1)+xShift ROI_coords(:,2)+yShift];
arm_coords(:,:,5)=[centers(:,1) ROI_coords(:,4)-yShift];
arm_coords(:,:,6)=[ROI_coords(:,3)-xShift ROI_coords(:,2)+yShift];

%% Set experiment parameters

exp_duration = exp_duration*60;                     % Convert duration from min. to seconds
referenceFreq = referenceFreq;                   
refStack=repmat(refImage,1,1,referenceStackSize);   % Create placeholder for 5-image rolling reference.
refCount=0;
aboveThresh=ones(10,1)*pixMean;                      % Num pixels above threshold last 5 frames
pixDev=ones(10,1);                                   % Num Std. of aboveThresh from mean
noiseCt=1;                                           % Frame counter for noise sampling
ct=1;                                                % Frame counter

% Time stamp variables
tempCount=1;
previous_tStamp=0;                  
tElapsed=0;
centStamp=zeros(size(ROI_coords,1),1);
turntStamp=zeros(size(ROI_coords,1),1);

previous_refUpdater=0;                          % Compared to current_refUpdater to update the reference at correct freq.
write=boolean(0);                               % Data written to hard drive when true

display=boolean(1);                             % Updates display every 2s when true
previous_arm=zeros(size(ROI_coords,1),1);


%% Run Experiment
shg
tic
while toc < exp_duration
    
        % Grab new time stamp
        current_tStamp = toc;
        tElapsed=tElapsed+current_tStamp-previous_tStamp;
        set(handles.edit8,'String',num2str(round(1/(current_tStamp-previous_tStamp))));
        previous_tStamp=current_tStamp;
        ct=ct+1;
        tempCount=tempCount+1;

        % Get framerate delay to slow acquisition
        delay=str2double(get(handles.edit9,'String'));
        delay=delay/1000;
        pause(delay);
    
        % Update clock in the GUI
        timeRemaining = round(exp_duration - toc);
        if timeRemaining < 60; 
            set(handles.edit6, 'String', ['00:00:' sprintf('%0.2d',timeRemaining)]);
            set(handles.edit6, 'BackgroundColor', [1 0.4 0.4]);
        elseif (3600 > timeRemaining) && (timeRemaining > 60);
            min = floor(timeRemaining/60);
            sec = rem(timeRemaining, 60);
            set(handles.edit6, 'String', ['00:' sprintf('%0.2d',min) ':' sprintf('%0.2d',sec)]);
            set(handles.edit6, 'BackgroundColor', [1 1 1]);
        elseif timeRemaining > 3600;
            hr = floor(timeRemaining/3600);
            min = floor(rem(timeRemaining, 3600)/60);
            sec = timeRemaining - hr*3600 - min*60;
            set(handles.edit6, 'String', [sprintf('%0.2d', hr) ':' sprintf('%0.2d',min) ':' sprintf('%0.2d',sec)]);
            set(handles.edit6, 'BackgroundColor', [1 1 1]);
        end
        
        % Capture frame and extract centroid
        imagedata=peekdata(vid,1);
        imagedata=imagedata(:,:,1);
        % Correct image for vignetting
        diffImage=(refImage-vignetteMat)-(imagedata-vignetteMat);           
        
        % update reference image and ROI_positions at the reference frequency and print time remaining 
        current_refUpdater=mod(toc,referenceFreq);
        aboveThresh(mod(ct,10)+1)=sum(sum(diffImage>imageThresh));
        pixDev(mod(ct,10)+1)=(nanmean(aboveThresh)-pixMean)/pixStd;
        
        % Only gather centroids and record turns if noise is below
        % threshold
        if pixDev(mod(ct,10)+1)<8

            % Extract image properties and exclude centroids not satisfying
            % size criteria
            props=regionprops((diffImage>imageThresh),propFields);
            validCentroids=([props.Area]>4&[props.Area]<120);
            cenDat=reshape([props(validCentroids).Centroid],2,length([props(validCentroids).Centroid])/2)';
            oriDat=reshape([props(validCentroids).Orientation],1,length([props(validCentroids).Orientation]))';
            
            % Match centroids to ROIs by finding nearest ROI center
            [lastCentroid,centStamp,tOriDat]=...
                optoMatchCentroids2ROIs(cenDat,oriDat,centers,speedThresh,distanceThresh,lastCentroid,centStamp,tElapsed);

            % Determine if fly has changed to a new arm
            [current_arm,previous_arm,changedArm,rightTurns,turntStamp]=...
                detectArmChange(lastCentroid,arm_coords,previous_arm,mazeOri,armThresh,turntStamp,tElapsed);

            turnArm=NaN(size(ROI_coords,1),1);
            turnArm(changedArm)=current_arm(changedArm);
            
            % Write data to the hard drive
            dlmwrite(cenID, lastCentroid', '-append');
            dlmwrite(oriID, [tElapsed oriDat'], '-append');
            dlmwrite(turnID, turnArm', '-append');
        end

        % Update the display every 30 frames
        if mod(ct,30)==0 && get(handles.togglebutton7,'value')==1
           %imagedata(:,:,1)=uint8((diffImage>imageThresh).*255);
           imshow((imagedata-vignetteMat))
           hold on
           plot(lastCentroid(:,1),lastCentroid(:,2),'o','Color','r')
           hold off
           drawnow
        end

        % Display current noise level once/sec
        if mod(ct,round(60/delay))==0
            currentDev=mean(pixDev)
        end
        
        % If noise in the image goes more than 6 std above mean, wipe the
        % old references and create new ones            

        if current_refUpdater<previous_refUpdater||mean(pixDev)>8
            
            % If noise is above threshold: reset reference stack,
            % aboveThresh, and pixDev
            % Otherwise, just update the stack with a new reference
            if mean(pixDev)>10
               refStack=repmat(imagedata(:,:,1),1,1,size(refStack,3));
               refImage=uint8(mean(refStack,3));
               aboveThresh=ones(10,1)*pixMean;
               pixDev=ones(10,1);
               disp('NOISE THRESHOLD REACHED, REFERENCES RESET')
            else
               % Update reference
               refCount=refCount+1;
               refStack(:,:,mod(size(refStack,3),refCount)+1)=imagedata(:,:,1);
               refImage=uint8(mean(refStack,3));
               % Update vignette offset matrix with better reference
               vignetteMat=decFilterVignetting(refImage,binaryimage,ROI_coords);
            end
        end 
        previous_refUpdater=current_refUpdater;
   
   if get(handles.togglebutton9, 'Value') == 1;
      waitfor(handles.togglebutton9, 'Value', 0)   
   end
end

%% Pull in ASCII data, format into matrices

disp('Experiment Complete')
disp('Importing Data - may take a few minutes...')

% Initialize data struct
flyTracks=[];
flyTracks.nFlies = size(ROI_coords,1);

% Import time stamp, orientation, turn, and centroid data and store in
% struct
tmpOri = dlmread(oriID);
flyTracks.tStamps=tmpOri(:,1);
flyTracks.orientation=tmpOri(:,2:end);
flyTracks.rightTurns=dlmread(turnID);
flyTracks.mazeOri=mazeOri;
flyTracks.labels = readtable(labelID);

tmp = dlmread(cenID);
centroid=NaN(size(tmp,1)/2,2,flyTracks.nFlies);
xCen=mod(1:size(tmp,1),2)==1;
yCen=mod(1:size(tmp,1),2)==0;

for k = 1:flyTracks.nFlies
    k
    centroid(:, 1, k) = tmp(xCen, k)';
    centroid(:, 2, k) = tmp(yCen, k)';
end

flyTracks.centroid=centroid;

%% Find index of first turn for each fly and discard to eliminate tracking artifacts

turns=flyTracks.rightTurns;
[r,c]=find(~isnan(turns));
c=[0;c];
t1rows=r(find(diff(c)));
c(1)=[];
t1cols=unique(c);

for i=1:length(t1cols)
    turns(t1rows(i),t1cols(i))=NaN;
end

% Update turn data with false turns discarded
flyTracks.rightTurns=turns;

%% Calculate turn probability
numTurns=sum(~isnan(turns));
flyTracks.numTurns=numTurns;
flyTracks.tSeq=NaN(max(flyTracks.numTurns),flyTracks.nFlies);

%{
Start by converting arm number turn sequence into compressed right turn
sequence by taking difference between subsequent maze arms. For either orientation 
of a maze, arms are 1 to 3 left to right. For example, for a rightside-up Y, 
right turns would be 1-3=-2, 3-2=1, and 2-1=1. The opposite is true for the
opposite orientation of a maze. In the output, tSeq, Right turns = 1, Left
turns = 0.
%}
for i=1:flyTracks.nFlies
    tSeq=flyTracks.rightTurns(~isnan(flyTracks.rightTurns(:,i)),i);
    tSeq=diff(tSeq);
    if flyTracks.mazeOri(i)
        flyTracks.tSeq(1:length(tSeq),i)=tSeq==1|tSeq==-2;
    elseif ~flyTracks.mazeOri(i)
        flyTracks.tSeq(1:length(tSeq),i)=tSeq==-1|tSeq==2;
    end
end

% Calculate right turn probability from tSeq
flyTracks.rBias=nansum(flyTracks.tSeq)./nansum(~isnan(flyTracks.tSeq));

%% Save data to struct
save(strcat(handles.fpath,'\',t,'Ymaze','.mat'),'flyTracks');


%% Plot histograms of the data

inc=0.05;
bins=-inc/2:inc:1+inc/2;   % Bins centered from 0 to 1 

c=histc(flyTracks.rBias(flyTracks.numTurns>40),bins); % histogram
mad(flyTracks.rBias(flyTracks.numTurns>40))           % MAD of right turn prob
c=c./(sum(c));
c(end)=[];
plot(c,'Linewidth',2);
set(gca,'Xtick',(1:length(c)),'XtickLabel',0:inc:1);
axis([0 length(bins) 0 max(c)+0.05]);

% Generate legend labels
strain='';
treatment='';
if iscellstr(flyTracks.labels{1,1})
    strain=flyTracks.labels{1,1}{:};
end
if iscellstr(flyTracks.labels{1,3})
    treatment=flyTracks.labels{1,3}{:};
end
legend([strain ' ' treatment ' (u=' num2str(mean(flyTracks.rBias(flyTracks.numTurns>40)))...
    ', n=' num2str(sum(flyTracks.numTurns>40)) ')']);
shg

%% Display command to load data struct into workspace

disp('Execute the following command to load your data into the workspace:')
disp(['load(',char(39),strcat(handles.fpath,'\',t,'flyTracks','.mat'),char(39),');'])
