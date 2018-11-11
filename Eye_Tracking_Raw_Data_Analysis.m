tic
%%Get the Folder Name and the list of all the images
folder= uigetdir (pwd, 'Select folder with .tiff files');
pic= dir (fullfile(folder,'*.tif') ); %imageJ has .tif
names= {pic.name};
im1= imread(strcat(folder, '\' ,names{1, 1}));
imSize= size(im1);
PupilArea = [];
StickerArea = [];
BlickedFrame = [];

%% For the pupil also 2 pixels equals one degree of movement.

%Select the appropriate region of interest (ROI) for the pupil
imshow(im1);
h= imrect;
pos = getPosition(h);
b = imSize(1, 1);

%Get the boundaries of the ROI and initialize the storePic array for 
%all the binary images.  
xlist = [round(pos(1, 1)) round(pos(1, 3))];
ylist = [round(pos(1, 2)) round(pos(1, 4))];
storePic=zeros(ylist(2)+1,xlist(2)+1,length(names),'uint8');

 parfor i= 1: length(names)
    image = imread(strcat(folder, '\' , names{1,i}));  
    BW = im2bw(image,0.04);  %might need changing it is basically val/255
    storePic(:,:,i) = BW(ylist(1):ylist(1)+ylist(2),xlist(1):xlist(1)+xlist(2));
    if mod(i,1000)==0
        disp(i)
        imshow(storePic(:,:,i),[0 1])
    end
 end
 toc

 %Initialize the ROI
 filtered=zeros(ylist(2)+1,xlist(2)+1,length(names),'uint8');
 Pupil_Loc=zeros(2,length(names));
 se = strel('disk',2);
 tic
 
 
for i= 1: length(names)
I = bwarea( ~(storePic(:,:,i)) );
PupilArea(i) = I;
end

parfor i=1:length(names)
    
    filtered=medfilt2(storePic(:,:,i));
    filtered=imclose(filtered,se);
    filtered=~filtered;
    CC = bwconncomp(filtered);
    S = regionprops(CC,'Centroid');
    numPixels = cellfun(@numel,CC.PixelIdxList);
    [biggest,idx] = max(numPixels);
    if PupilArea(i)>1500 %Accounts for blinks
        centers=S(idx).Centroid;
        Pupil_Loc(:,i)=centers;
    else
        Pupil_Loc(:,i)=[0,0];
    end
    
 end
 toc
 
 for i= 1: length(names)
     I = bwarea( imcomplement(storePic(:,:,i)) );
     PupilArea(i) = I;
 end

 
 
%% For the sticker
 
close all
imshow(im1);
h= imrect;
pos = getPosition(h);

xlist = [round(pos(1, 1)) round(pos(1, 3))];
ylist = [round(pos(1, 2)) round(pos(1, 4))];
storePic=zeros(ylist(2)+1,xlist(2)+1,length(names),'uint8');

%automate the sticker threshold
 parfor i= 1: length(names) 
    image = imread(strcat(folder, '\' , names{1,i}));  
    BW = im2bw(image,0.14); %might need changing it is basically val/255
    storePic(:,:,i) = BW(ylist(1):ylist(1)+ylist(2),xlist(1):xlist(1)+xlist(2));
    if mod(i,1000)==0
        disp(i) 
        imshow(storePic(:,:,i))
    end
 end

 %We also have an option to use binary 
 %operations on an image to clean it up more, the
 %strel function allows us to do so  when we use 
 %imclose.  
 
se = strel('disk',2);

for i= 1: length(names)
I = bwarea( (storePic(:,:,i)) );
PupilArea(i) = I;
end

Stick_Loc=zeros(2,length(names));
tic
parfor i=1:length(names)
    filtered=medfilt2(storePic(:,:,i));
    %For eyeliner, thanks to janice!!!
    filtered=~filtered;
    if mod(i,1000)==0
        disp(i)
        imshow(filtered)
    end
    CC = bwconncomp(filtered);
    S = regionprops(CC,'Centroid');
    numPixels = cellfun(@numel,CC.PixelIdxList);
    [biggest,idx] = max(numPixels);
    if PupilArea(i)>2
        centers=S(idx).Centroid;
        Stick_Loc(:,i)=centers;
    else
        Stick_Loc(:,i)=[100,40];
    end
end
toc

Stick_Loc_Off=Stick_Loc(1,1:length(names))'-Stick_Loc(1,1);
Pupil_Loc_Off=Pupil_Loc(1,1:length(names))'-Pupil_Loc(1,1);



Net_X=Pupil_Loc_Off-Stick_Loc_Off;

Stick_Loc_Off_y=Stick_Loc(2,1:length(names))'-Stick_Loc(2,1);
Pupil_Loc_Off_y=Pupil_Loc(2,1:length(names))'-Pupil_Loc(2,1);
Net_Y=Pupil_Loc_Off_y-Stick_Loc_Off_y;

 for i= 1: length(names)
     I = bwarea( storePic(:,:,i) );
     StickerArea{i, 1} = I;
 end
 
 %% Analyze the monitor
 % find the average of the steady states and take that as the start time
%  
%  Time2=[];
%  RunTime=0;
%  for i=1:length(Time)  
%     RunTime=Time(i)+RunTime;
%     Time2(i)=RunTime;
%  end
%  
 monitorAvg=smooth(Monitor,9);

 
 for i=1:length(monitorAvg)
    if monitorAvg(i)>20
        monitorAvg(i)=80;
    end
 end
 
 monitor_diff=diff([0;monitorAvg]);
 plot(monitor_diff)
 
 falling=[];
 rising=[];
 fall=1;
 rise=1;
 for i=1:length(monitor_diff)
    if monitor_diff(i)>30
        rising(rise)=i;
        rise=rise+1;
    elseif monitor_diff(i)<-30
        falling(fall)=i;
        fall=fall+1;
    end
    
 end
 
 %% Now fix the Net_X direction of movement
for j=1:30
 diff_X=diff([0;Net_X]);
 for i=1:length(diff_X)
    if abs(diff_X(i))>0.05
        Net_X(i)=NaN;
    end
 end
end



 
 