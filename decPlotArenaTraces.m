function out=decPlotArenaTraces(flyCircles,raw_data)

numFlies=length(flyCircles);

for i=1:numFlies
arena(i).trace_ends=find(diff(flyCircles(i).valid_trials)>1);
arena(i).numTraces=sum(diff(flyCircles(i).valid_trials)>1);
arena(i).x=raw_data(flyCircles(i).valid_trials,i*2);
arena(i).y=raw_data(flyCircles(i).valid_trials,i*2+1);

end

colors = rand(1,3,numFlies);
numFigures=ceil(numFlies/10);
bins=0:2*pi/16:2*pi;
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

        for j=1:arena(i).numTraces
            if j==1
            tempxTrace=arena(i).x(1:arena(i).trace_ends(i));
            tempyTrace=arena(i).y(1:arena(i).trace_ends(i));
            tempAngles=flyCircles(i).circum_vel(1:arena(i).trace_ends(i));
            else
            tempxTrace=arena(i).x(arena(i).trace_ends(j-1)+1:arena(i).trace_ends(j));
            tempyTrace=arena(i).y(arena(i).trace_ends(j-1)+1:arena(i).trace_ends(j));
            tempAngles=flyCircles(i).circum_vel(arena(i).trace_ends(j-1)+1:arena(i).trace_ends(j));
            end
            z=zeros(size(tempxTrace));
            mu=-sin(tempAngles);
            if length(tempxTrace)~=1
            surface([tempxTrace';tempxTrace'],[tempyTrace';tempyTrace'],[z';z'],[mu';mu'],...
                'facecol','no','edgecol','interp','linew',0.5);
            end
        end

    % Plot angle histogram
    hold on
    subplot(5,5,subP+5);
    h1=plot(bins,flyCircles(i).angleavg,'color',colors(:,:,i));
    xLabels={'0';'pi/2';'pi';'3pi/2'};
    set(gca,'Xtick',[0:pi/2:3*pi/2],'XtickLabel',xLabels)
    set(h1,'Linewidth',2)
    legend(['u=' num2str(flyCircles(i).mu)],'Location','southeast')
    legend('boxoff')
    axis([0,2*pi,0,0.16]);

    %Plot mu
    %{
    subplot(3,1,3);
    hold on
    y=0;
    h2 = plot(-sin(flyCircles(j).avg),y,'color',colors(:,:,j));
    set(h2,'marker','o');
    axis([-1,1,-1,1]);
    %}

       if subP==5
            k=k+1;
       end 
       

    
end

end



