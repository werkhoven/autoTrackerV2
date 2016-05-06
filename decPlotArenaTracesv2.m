function out=decPlotArenaTracesv2(flyCircles,raw_data,ROI_coords)

numFlies=length(flyCircles);
traces=NaN(floor(size(raw_data,1)/60),numFlies*2);
traceMask=mod(1:floor(size(raw_data,1)/60)*60,60)==0;
traces=raw_data(traceMask,:);
traces(:,1)=[];
traceMask=boolean([traceMask zeros(1,size(raw_data,1)-size(traceMask,2))]);

colors = rand(1,3,numFlies);
numFigures=ceil(numFlies/10);
bins=0:2*pi/25:2*pi;
bins(end)=[];


for i=1:numFlies
    i
   if mod(i-1,10)==0
       figure()
       k=0;
   end
    subP=mod(i-1,5)+1+k*10;

    %Plot fly trace
    hold on
    subplot(5,5,subP);

            xTrace=traces(:,i*2-1)-ROI_coords(i,1);
            yTrace=traces(:,i*2)-ROI_coords(i,2);
            tmpAngle=flyCircles(i).circum_vel;
            tmpAngle=tmpAngle(traceMask);
            z=zeros(size(xTrace));
            mu=-sin(tmpAngle);
            surface([xTrace';xTrace'],[yTrace';yTrace'],[z';z'],[mu';mu'],...
                'facecol','no','edgecol','interp','linew',0.5);


    % Plot angle histogram
    hold on
    subplot(5,5,subP+5);
    h1=plot(bins,flyCircles(i).angleavg,'color',colors(:,:,i));
    xLabels={'0';'pi/2';'pi';'3pi/2'};
    set(gca,'Xtick',[0:pi/2:3*pi/2],'XtickLabel',xLabels)
    set(h1,'Linewidth',2)
    legend(['u=' num2str(flyCircles(i).mu)],'Location','northeast')
    legend('boxoff')
    axis([0,2*pi,0,0.25]);

       if subP==5
            k=k+1;
       end 
       

    
end

end



