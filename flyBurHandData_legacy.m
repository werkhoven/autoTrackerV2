function out=flyBurHandData_legacy(data,numFlies,roi)

    out=[];

for j=1:numFlies
    inx=data(:,2*j);
    iny=data(:,2*j+1);
    
    out(j).r=sqrt((inx-roi/2).^2+(iny-roi/2).^2);
    out(j).theta=atan2(iny-roi/2,inx-roi/2);
    out(j).direction=zeros(size(inx,1),1);
    out(j).speed=zeros(size(inx,1),1);
    out(j).width=roi;
    out(j).direction(2:end)=atan2(diff(iny),diff(inx));
    out(j).speed(2:end)=sqrt(diff(iny).^2+diff(iny).^2);
    out(j).speed(out(j).speed>12)=NaN;
end

