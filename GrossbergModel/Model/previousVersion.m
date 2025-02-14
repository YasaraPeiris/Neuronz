function previousVersion()

t1 = tic;

global imageFile kernelG1 Row Col;

setParameters();

fileList = folderDetails();

%{
for name = fileList
    imageFile = cell2mat(name);
    init();
    run();
    disp(name);
end
%}


name = fileList{1}; % 9, 14, 17, 23, 24, 25, 26, 30, 35*, 43**, 48

imageFile = name;

t2 = tic;
init();
%disp(toc(t2));

t3 = tic;
run();
%disp(toc(t3));

disp('Overall runtime:');
disp(toc(t1));

disp(name);

%I = mat2gray(full(vec2mat(kernelG1(floor(Row * Col / 2 - Col / 2), :)', Col)));
%imshow(I);

disp('Done');

function setParameters()

global kernelG1 kernelG2 sigma1 sigma2 dc alpha C1 C2 gamma w Wrange incidenceW kernelWplus kernelWminus dw C3 eta;

kernelG1 = [];
kernelG2 = [];
incidenceW = [];
kernelWplus = cell(4);
kernelWminus = cell(4);

sigma1 = 1; % Equation (3), (4), (9)   default 1
sigma2 = 1; % Equation (10), (11)  default 0.5
dc = 0.001; % Equation  (6), (7), (20) default 0.25   0.025
alpha = 0.005; % Equation  (22)  % deafault 0.5
C1 = 1.0; % Equation (8)   default 1.5
C2 = 0.5; % Equation (9) default 0.075
gamma = 1.0; % Equation (14), (15), (17)  default 10.0 
w = 0.6; % Equation (17) default 6.0 
Wrange = 7;
dw = 0.001;
C3 = 0.6; % default 6.0
eta = 2.0;


%{
function init()
global image Row Col rightVertical leftVertical;
[image, Row, Col] = readImage();
rightVertical = [];
leftVertical = [];
%}

%{
function result = folderDetails()
global inputFolder;
[inputFolder, ~, ~] = fileparts(which(mfilename));
inputFolder = fullfile(inputFolder, '..', 'InitialCodes\ImageSamples1');
index = dir(inputFolder);
fileList = {index.name};
fileList = fileList(:, 3 : end);
result = fileList;
%}

%{
function [result, r, c] = readImage()
global inputFolder imageFile rawImage;
rawImage = imread(fullfile(inputFolder, imageFile));
if(size(rawImage, 3) == 3)
    rawImage = rgb2gray(rawImage);
end
result = double(rawImage);
[r, c] = size(result);
result = result';
result = result(:);
%}

function run()

global rawImage Row Col rightVertical leftVertical upHorizontal downHorizontal kernelG2 sigma2 gamma w;

len = Row * Col;

uplus = retinaOnCentre(); % Equation (5)
uminus = -uplus;
uplus_rectified = max(uplus, 0);
uminus_rectified = max(uminus, 0);
vplus = zeros(len, 1);
vminus = zeros(len, 1);
C = zeros(len, 2); % Column 1 vertical, column 2 horizontal
x = zeros(len, 2); % Column 1 vertical, column 2 horizontal
y = zeros(len, 2); % Column 1 vertical, column 2 horizontal
m = zeros(len, 2); % Column 1 vertical, column 2 horizontal
Rplus = [[], []];
Lplus = [[], []];
Rminus = [[], []];
Lminus = [[], []];

t5 = tic;
kernelG2 = gaussian(sigma2);
W();
upHorizontal = incidenceHorizontalUp();
downHorizontal = incidenceHorizontalDown();
rightVertical = incidenceVerticalRight();
leftVertical = incidenceVerticalLeft();

%disp(issparse(rightVertical));
%disp(nnz(kernelG2)/numel(kernelG2));
%disp(nnz(rightVertical)/numel(rightVertical));
%disp(nnz(leftVertical)/numel(leftVertical));
%disp('Runtime for G2:');
%disp(toc(t5));

iterations = 100;
gridSize = floor(sqrt(iterations)) + 1;
t = 1 : iterations;
normC = [];
normVplus = [];
normVminus = [];
normX = [];

t6 = tic;

for r = 1 : iterations
    x = layer6(x, C);  % Equation (22)
        
    [vplus, vminus] = LGN(vplus, vminus, uplus_rectified, uminus_rectified, x); % Equations (6), (7), (8), (9)
    vplus_rectified = max(vplus, 0);
    vminus_rectified = max(vminus, 0);
  
    %vertical Orientation
    [Rplus(:, 1), Lminus(:, 1)] = rightVerticalSimpleCells(vplus_rectified, vminus_rectified);
    [Rminus(:, 1), Lplus(:, 1)] = leftVerticalSimpleCells(vplus_rectified, vminus_rectified);
   
    %horizontal Orientation - Yasara
    [Rplus(:, 2), Lminus(:, 2)] = downHorizontalSimpleCells(vplus_rectified, vminus_rectified);
    [Rminus(:, 2), Lplus(:, 2)] = upHorizontalSimpleCells(vplus_rectified, vminus_rectified);
    
    SR = Rplus + Lminus;  % Equation (12)
    SL = Rminus + Lplus; % Equation (13)
    Splus = Rplus + Lplus;
    Sminus = Rminus + Lminus;
    temp1 = SR - SL;
    temp2 = Splus - Sminus;
    
    C = gamma * max(temp1, 0) + gamma * max(-temp1, 0) - w * max(temp2, 0) - w * max(-temp2, 0); % Equatuion (17)
    
    m = layer4Inhibitory(m, x);
    
    y = layer4(y, C, m, x);
    
    trainW(m, y);
    
    normC = [normC, norm(C,'fro')];
    normVplus = [normVplus, norm(vplus_rectified, 'fro')];
    normVminus = [normVminus, norm(vminus_rectified, 'fro')];
    normX = [normX, norm(x, 'fro')];
    
    %showImages(C, r, strcat('Iteration: ', int2str(r)), gridSize);
    
end

disp(strcat('Runtime for iterations = ', iterations));
disp(toc(t6));

%showImages(rawImage, iterations + 1, 'Original Image', gridSize);

showFinalImage(uplus);
showFinalImage(uminus);
showFinalImage(vplus);
showFinalImage(vminus);
showFinalImage(SR(:, 1));
showFinalImage(SR(:, 2));
showFinalImage(SL(:, 1));
showFinalImage(SL(:, 2));
%showFinalImage(y(:, 1));
%showFinalImage(y(:, 2));
showFinalImage(sum(y, 2));

global kernelWplus;

temp = kernelWplus{2};

%showFinalImage(full(temp(40000, :)'));
%showFinalImage(full(temp(50000, :)'));

plotPerformance(t, normC, normVplus, normVminus, normX);
%saveImage(C);
drawnow;

% Equation (5)
function result = gaussian(sigma)

global Row Col;

fileName = fullfile(fileparts(which(mfilename)), 'Gaussians', strcat(num2str(Row), '_', num2str(Col), '_', num2str(sigma), '.mat'));

if exist(fileName, 'file') == 2
    load(fileName, 'result');
    return;
end

a = floor(Row / 2);
b = floor(Col / 2);

I = [1 : Row]' * ones(1, Col);
J = ones(Row, 1) * [1 : Col];
M = exp(-((a - I).^2 + (b - J).^2) / (2 * sigma^2)) / (2 * pi * sigma^2);
M(M < 10 ^ (-6)) = 0;

result = prepareKernel(a, b, Row, Col, M);

save(fileName, 'result');


function W()

global Row Col Wrange incidenceW kernelWplus kernelWminus;

fileName = fullfile(fileparts(which(mfilename)), 'Wkernels', strcat(num2str(Row), '_', num2str(Col), '_', num2str(Wrange), '.mat'));

if exist(fileName, 'file') == 2
    load(fileName, 'incidenceW', 'kernelWplus', 'kernelWminus');
    return;
end

a = floor(Row / 2);
b = floor(Col / 2);
len = Row * Col;

I = [1 : Row]' * ones(1, Col);
J = ones(Row, 1) * [1 : Col];
M = sqrt((I - a) .^2 + (J - b) .^2);
M = double(M < Wrange / 2);
incidenceW = prepareKernel(a, b, Row, Col, M)';

for i = 1 : 4
    kernelWplus{i} = sparse(len, len);
    kernelWminus{i} = sparse(len, len);
end

save(fileName, 'incidenceW', 'kernelWplus', 'kernelWminus');


% Equation (3)
function result = retinaOnCentre()

global image kernelG1 sigma1;

t4 = tic;
kernelG1 = gaussian(sigma1);
%disp('Runtime for G1:');
%disp(toc(t4));

result = image - kernelG1 * image;

% Equation (22)
function result = layer6(x, C)

global dc alpha;

result = x + dc * (-x + alpha * (1 - x) .* C);

% Equations (6), (7), (8), (9) 
function [result1, result2] = LGN(vplus, vminus, uplus_rectified, uminus_rectified, x)

global dc C1 C2 kernelG1;

temp = sum(x, 2);

A = C1 * temp; % Equation (8)
B = C2 * kernelG1 * temp; % Equation (9)
result1 = vplus + dc * (-vplus + (1 - vplus) .* uplus_rectified .* (1 + A) - (vplus + 1) .* B); % Equation (6)
result2 = vminus + dc * (-vminus + (1 - vminus) .* uminus_rectified .* (1 + A) - (vminus + 1) .* B); % Equation (7)

% Equations (10), (11)
function [result1, result2] = rightVerticalSimpleCells(vplus, vminus)

global rightVertical leftVertical ;

Rplus = rightVertical * vplus; % Equation (10)
Lminus = leftVertical * vminus; % Equation (11)

result1 = Rplus;
result2 = Lminus;


% Equations (10), (11)
function [result1, result2] = leftVerticalSimpleCells(vplus, vminus)
global rightVertical leftVertical ;

Rminus = rightVertical * vminus; % Equation (10)
Lplus = leftVertical * vplus; % Equation (11)

result1 = Rminus;
result2 = Lplus;


% Equations (10), (11)
%upHorizontalSimpleCells - Yasara
function [result1, result2] = upHorizontalSimpleCells(vplus, vminus)

global upHorizontal downHorizontal ;

Rplus = upHorizontal * vplus; % Equation (10)
Lminus = downHorizontal * vminus; % Equation (11)

result1 = Rplus;
result2 = Lminus;


% Equations (10), (11)
%downHorizontalSimpleCells - Yasara
function [result1, result2] = downHorizontalSimpleCells(vplus, vminus)

global upHorizontal downHorizontal ;

Rminus = upHorizontal * vminus; % Equation (10)
Lplus = downHorizontal * vplus; % Equation (11)

result1 = Rminus;
result2 = Lplus;


function trainW(m, y)

global Row Col incidenceW kernelWplus kernelWminus dw C3;

len = Row * Col;

index = [1, 1; 1, 2; 2, 1; 2, 2]; % vertical - 1, horizontal - 2

M = cell(2);

M{1} = spdiags(m(:, 1), 0, len, len);
M{2} = spdiags(m(:, 2), 0, len, len);

Y = cell(2);

Y{1} = spdiags(y(:, 1), 0, len, len);
Y{2} = spdiags(y(:, 2), 0, len, len);
%{
disp(size(M{1}));
disp(size(Y{1}));
disp(size(kernelWplus{1}));
disp(size(incidenceW));
%}

for t = 1 : 4  % 1 - v & v, 2 - v & h, 3 - h & v, 4 - h & h 
    
    kernelWminus{t} = kernelWminus{t} + dw * (M{index(t, 1)} * incidenceW * M{index(t, 2)} - M{index(t, 1)} * kernelWminus{t}); % Equation (37)
    kernelWplus{t} = kernelWplus{t} + dw * (C3 * M{index(t, 1)} * incidenceW * Y{index(t, 2)} - M{index(t, 1)} * kernelWplus{t}); % Equation (38)
    
end


function result = layer4Inhibitory(m, x)

global dc eta kernelWminus;

temp = [(kernelWminus{1} * m(:, 1) + kernelWminus{3} * m(:, 2)), (kernelWminus{2} * m(:, 1) + kernelWminus{4} * m(:, 2))];

result = m + dc * ( - m + (eta * x) .^2 - m .* temp);


function result = layer4(y, C, m, x)

global dc eta kernelWplus;

temp = [(kernelWplus{1} * m(:, 1) + kernelWplus{3} * m(:, 2)), (kernelWplus{2} * m(:, 1) + kernelWplus{4}' * m(:, 2))];

result = y + dc * (-y + (1 - y) .* (C + eta * x) - (1 + y) .* temp);



function result = incidenceVerticalRight()

global Row Col sigma2 kernelG2;

%{
block = eye(Col - sigma2);
block = [zeros(Col - sigma2, sigma2), block];
block = [block; [zeros(sigma2, Col - 1), ones(sigma2, 1)]];
block = sparse(block);
%}


block = spdiags(ones(Col, 1), sigma2, Col, Col);
block(Col - sigma2 + 1 : end, end) = 1;


%disp(nnz(block)/numel(block));

%disp(block);

result = kron(speye(Row),block) * kernelG2;


function result = incidenceVerticalLeft()

global Row Col sigma2 kernelG2;

%{
block = eye(Col - sigma2);
block = [block, zeros(Col - sigma2, sigma2)];
block = [[ones(sigma2, 1), zeros(sigma2, Col - 1)]; block];
block = sparse(block);
%}

block = spdiags(ones(Col, 1), -sigma2, Col, Col);
block(1 : sigma2, 1) = 1;

%disp(nnz(block)/numel(block));

%disp(block);

result = kron(speye(Row),block) * kernelG2;

%incidenceHorizontalUp - Yasara
function result = incidenceHorizontalDown()

global Row Col sigma2 kernelG2;

new_block = speye(Col);
block = spdiags(ones(Row, 1), sigma2, Row, Row);
block(Row - sigma2 + 1 : end, end) = 1;

result = kron(block,new_block) * kernelG2;

%incidenceHorizontalDown - Yasara
function result = incidenceHorizontalUp()

global Row Col sigma2 kernelG2;

new_block = speye(Col);
block = spdiags(ones(Row, 1), -sigma2, Row, Row);
block(1 : sigma2, 1) = 1;

result = kron(block,new_block) * kernelG2;

function result = prepareKernel(a, b, r, c, M)

M = sparse(M);
M = M';
v = ones(c, 1);
D1 = spdiags(v, 1, c, c);
D2 = spdiags(v, -1, c, c);

temp = M;
tempResult = reshape(M, 1, numel(M));

for k = 1: b - 1;
    temp = D1 * temp;
    tempResult = [reshape(temp, 1, numel(temp)); tempResult];
end

temp = M;

for k = 1: c - b;
    temp = D2 * temp;
    tempResult = [tempResult; reshape(temp, 1, numel(temp))];
end

temp = tempResult;
result = temp;
v = ones(r * c, 1);
D1 = spdiags(v, c, r * c, r * c);
D2 = spdiags(v, -c, r * c, r * c);

for k = 1: a - 1;
    temp = temp * D2;
    result = [temp; result];
end

temp = tempResult;

for k = 1: r - a;
    temp = temp * D1;
    result = [result; temp];
end

%{
function saveImage(C)
global inputFolder imageFile Row rawImage
I = vec2mat(C, Row);
I = mat2gray(I);
I = cat(2, I, mat2gray(rawImage));
imwrite(I, fullfile(inputFolder, '..', 'Processed', strcat('processed', imageFile)));
%}

%{
function showImages(C, r, imTitle, size)
global Col;
subplot(size, size, r);
%I = vec2mat(max(C, max(C) / 10), Row);
I = vec2mat(C, Col);
I = mat2gray(I);
imshow(I);
title(imTitle);
%}

%{
function showFinalImage(C)
global Col;
%I = vec2mat(max(C, max(C) / 10), Row);
figure
I = vec2mat(C, Col);
I = mat2gray(I);
imshow(I);
%}

%{
function plotPerformance(t, normC, normVplus, normVminus, normX)
%subplot(size, size, index);
figure
plot(t, normC, 'b', t, normVplus, 'g', t, normVminus, 'r', t, normX, 'y');
legend('ComplexCells', 'LGN On', 'LGN Off', 'Layer 6');
%}