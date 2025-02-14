function orientationRF()

t1 = tic;

global imageFile image Row Col kernelH kernelV kernelU;

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


%name = fileList{3}; % 9, 14, 17, 23, 24, 25, 26, 30, 35*, 43**, 48

%imageFile = name;

tests = 500;

%init();
Row = 50;
Col = 50;

norm1 = [];
norm2 = [];
norm3 = [];
norm4 = [];

initStructs();

for i = 1 : tests

    imageFile = fileList{randi(length(fileList))};
    [image, ~, ~] = readImage();
    run(0);

    temp = kernelH;
    
    norm1 = [norm1, norm(temp{1}, 'fro')];
    norm2 = [norm2, norm(temp{2},'fro')];
    norm3 = [norm3, norm(temp{3}, 'fro')];
    norm4 = [norm4, norm(temp{4}, 'fro')];
     
    disp(i);
    
end

disp('Overall runtime:');
disp(toc(t1));

len = Row * Col;

temp1 = kernelV{3};
[~, ind] = max(temp1(:));
[r, c] = ind2sub([len, len], ind);
showFinalImage(full(temp1(r, :)'));

temp2 = kernelH;

disp(sum(sum(temp2{1} ~= 0)) / numel(temp2{1}));
disp(sum(sum(temp2{2} ~= 0)) / numel(temp2{2}));
disp(sum(sum(temp2{3} ~= 0)) / numel(temp2{3}));
disp(sum(sum(temp2{4} ~= 0)) / numel(temp2{4}));

t = 1 : tests;

plotPerformance(t, norm1, norm2, norm3, norm4);

for i = 1 : 5

    imageFile = fileList{randi(length(fileList))};
    [image, ~, ~] = readImage();
    run(1);
    
end

disp('Done');

function setParameters()

global kernelG1 kernelG2 sigma1 sigma2 dc da dv epsilon shi alpha beta C1 C2 gamma w Wrange Hrange Utotal T incidenceW incidenceU kernelWplus kernelWminus kernelU distanceU kernelV kernelH kernelTplus kernelTminus dw C3 eta phi k tau lambda a b;

kernelG1 = [];
kernelG2 = [];
incidenceW = [];
incidenceU = [];
distanceU = [];
kernelWplus = cell(4);
kernelWminus = cell(4);
kernelU = cell(4);
kernelV = cell(4);
kernelH = cell(4);
kernelTplus = cell(4);
kernelTminus = cell(4);

sigma1 = 1.0; % Equation (3), (4), (9)   default 1 (must be integers)
sigma2 = 1.0; % Equation (10), (11)  default 0.5 (must be integers)
dc = 0.001; % Equation  (6), (7), (20), (26), (28) default 0.25   0.025 0.001
da = 0.25;  % Equation (29) default 0.25
dv = 0.5;   % Equation (33) default 0.5
epsilon = 0.01; % Equation (34) default 0.01
shi = 1.0;  % Equation (22), (24) default 2.0 
alpha = 0.005; % Equation  (22) default 0.5    0.005
beta = 8.0; % Equation (31) default 8.0
C1 = 1.0; % Equation (8)   default 1.5   1.0
C2 = 0.5; % Equation (9) default 0.075   0.5
gamma = 1.0; % Equation (14), (15), (17)  default 10.0   1.0
w = 0.6; % Equation (17) default 6.0   0.6
Wrange = 7.0; % Equation (39) default 7.0
Hrange = 11.0;    % Equation (32) default 11.0 
Utotal = 44.0;  % Equation (29) default 44.0
T = 0.1;    % Equation (23) default 0.1
dw = 0.001; % Equation (35) - (38)
C3 = 0.6; % Equation (38) default 6.0   0.6
eta = 2.0; % Equation (25) default 2.0
phi = 0.01; % Equation (29) default 0.01
k = 6.0;    % Equation (30) default 6.0
tau = 1.5;  % Equation (35) default 1.5
lambda = 1.25;  % Equation (26) default 1.25  0.5
a = 0.125;
b = 1.0;


function run(runtype)

global Row Col image;

len = Row * Col;

%initStructs();

uplus = retinaOnCentre(); % Equation (5)
uplus_rectified = max(uplus, 0);
uminus_rectified = max(-uplus, 0);
%uplus_rectified(uplus_rectified < 0.9) = 0;
%uminus_rectified(uminus_rectified < 0.9) = 0;
vplus = zeros(len, 1);
vminus = zeros(len, 1);
C = zeros(len, 2); % Column 1 vertical, column 2 horizontal
x = zeros(len, 2); % Column 1 vertical, column 2 horizontal
y = zeros(len, 2); % Column 1 vertical, column 2 horizontal
m = zeros(len, 2); % Column 1 vertical, column 2 horizontal
z = zeros(len, 2); % Column 1 vertical, column 2 horizontal
s = zeros(len, 2); % Column 1 vertical, column 2 horizontal

iterations = 5;
gridSize = floor(sqrt(iterations)) + 1;
t = 1 : iterations;
normX = [];
normY = [];
normZ = [];
normS = [];

for r = 1 : iterations
    
    %disp(r);
        
    [vplus, vminus] = LGN(vplus, vminus, uplus_rectified, uminus_rectified, x); % Equations (6), (7), (8), (9)
    
    C = poolLGN(vplus, vminus); % Equations (10) - (19)
    
    x = layer6(x, C, z);  % Equation (22)
    
    m = layer4Inhibitory(m, x); % Equation (25)
    
    y = layer4(y, C, m, x); % Equation (21)
    
    [z, s] = layer2_3(z, s, y); % Equations (26), (28)
    
    trainW(m, y);   % Equations (37), (38)
    trainUV(z); % Equations (27), (29) - (34)
    trainT(z, s);   % Equations (35), (36)
    
    %{
    normX = [normX, norm(x, 'fro')];
    normY = [normY, norm(y,'fro')];
    normZ = [normZ, norm(z, 'fro')];
    normS = [normS, norm(s, 'fro')];
    
    %showImages(C, r, strcat('Iteration: ', int2str(r)), gridSize);
    %}
    
end

if runtype
    %showFinalImage(sum(C, 2));
    %showFinalImage(z(:, 1));
    %showFinalImage(z(:, 2));
    %showFinalImage([image, sum(C, 2), sum(z, 2)]);
    figure
    imshow(vec2mat([mat2gray(image); mat2gray(sum(C, 2)); mat2gray(sum(z, 2))], Col));
end

%{
%showImages(rawImage, iterations + 1, 'Original Image', gridSize);


global kernelTplus kernelTminus kernelH kernelU kernelV kernelWplus kernelWminus;

temp = kernelV{1};

[~, ind] = max(temp(:));
[r, c] = ind2sub([len, len], ind);
disp(r);
disp(c);

showFinalImage(full(temp(r, :)'));

disp(sum(sum(kernelH{1} ~= 0)) / numel(kernelH{1}));
disp(sum(sum(kernelH{2} ~= 0)) / numel(kernelH{2}));
disp(sum(sum(kernelH{3} ~= 0)) / numel(kernelH{3}));
disp(sum(sum(kernelH{4} ~= 0)) / numel(kernelH{4}));

%plotPerformance(t, normX, normY, normZ, normS);
%saveImage(C);
drawnow;
%}

% Network simulation and neuronal output


% Equation (3)
function result = retinaOnCentre()

global image kernelG1;

t4 = tic;
%disp('Runtime for G1:');
%disp(toc(t4));

result = image - kernelG1 * image;

% Equation (22)
function result = layer6(x, C, z)

global dc alpha shi T;

F = z;
F(F <= T) = 0;

temp = alpha * C + shi * F;

%result = x + dc * (-x + (1 - x) .* temp);

result = 1 - 1 ./ (1 + temp); % Equation (24)

% Equations (6), (7), (8), (9) 
function [result1, result2] = LGN(vplus, vminus, uplus_rectified, uminus_rectified, x)

global dc C1 C2 kernelG1;

temp = sum(x, 2);

A = C1 * temp; % Equation (8)
B = C2 * kernelG1 * temp; % Equation (9)

%result1 = vplus + dc * (-vplus + (1 - vplus) .* uplus_rectified .* (1 + A) - (vplus + 1) .* B); % Equation (6)
%result2 = vminus + dc * (-vminus + (1 - vminus) .* uminus_rectified .* (1 + A) - (vminus + 1) .* B); % Equation (7)


temp1 = uplus_rectified .* (1 + A);
temp2 = uminus_rectified .* (1 + A);

result1 = (temp1 - B) ./ (1 + temp1 + B);
result2 = (temp2 - B) ./ (1 + temp2 + B);


% Equations (12) - (19)
function result = poolLGN(vplus, vminus)

global gamma w;

Rplus = [[], []];
Lplus = [[], []];
Rminus = [[], []];
Lminus = [[], []];

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

result = gamma * max(temp1, 0) + gamma * max(-temp1, 0) - w * max(temp2, 0) - w * max(-temp2, 0); % Equatuion (17)

% Equation (25)
function result = layer4Inhibitory(m, x)

global dc eta kernelWminus;

temp = [(kernelWminus{1} * m(:, 1) + kernelWminus{2} * m(:, 2)), (kernelWminus{3} * m(:, 1) + kernelWminus{4} * m(:, 2))];

%result = m + dc * ( - m + (eta * x) .^2 - m .* temp);

result = (eta * x) .^2 ./ (1 + m .* temp);

% Equation (21) / (20)
function result = layer4(y, C, m, x)

global dc eta kernelWplus;

temp = [(kernelWplus{1} * m(:, 1) + kernelWplus{2} * m(:, 2)), (kernelWplus{3} * m(:, 1) + kernelWplus{4} * m(:, 2))];

%result = y + dc * (-y + (1 - y) .* (C + eta * x) - (1 + y) .* temp);

result = (C + eta * x - temp) ./ (1 + C + eta * x + temp);

% Equation (26), (28)
function [result1, result2] = layer2_3(z, s, y)

global kernelH kernelTplus kernelTminus lambda T dc a b;

F = z;
F(F <= T) = 0;

temp1 = [(kernelH{1} * F(:, 1) + kernelH{2} * F(:, 2)), (kernelH{3} * F(:, 1) + kernelH{4} * F(:, 2))];
temp2 = [(kernelTplus{1} .* s(:, 1) + kernelTplus{2} .* s(:, 2)), (kernelTplus{3} .* s(:, 1) + kernelTplus{4} .* s(:, 2))];
temp3 = [(kernelTminus{1} .* s(:, 1) + kernelTminus{2} .* s(:, 2)), (kernelTminus{3} .* s(:, 1) + kernelTminus{4} .* s(:, 2))];

%result1 = z + dc * ( -z + (1 - z) .* (lambda * max(y, 0) + max(temp1 - temp2, 0)));
%result2 = s + dc * ( - s + temp1 - s .* temp3);


result1 = 1 - 1 ./ (1 + lambda * max(y, 0) + max(a * temp1 - b * temp2, 0));
result2 = temp1 ./ (1 + temp3);


% Kernel training

% Equations (37), (38)
function trainW(m, y)

global Row Col incidenceW kernelWplus kernelWminus dw C3;

len = Row * Col;

index = [1, 1; 1, 2; 2, 1; 2, 2]; % vertical - 1, horizontal - 2 (k, r)

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
    
    kernelWminus{t} = kernelWminus{t} + dw * (M{index(t, 1)} * incidenceW * M{index(t, 2)} -  kernelWminus{t} * M{index(t, 2)}); % Equation (37)
    kernelWplus{t} = kernelWplus{t} + dw * (C3 * M{index(t, 1)} * incidenceW * Y{index(t, 2)} - kernelWplus{t} * M{index(t, 2)}); % Equation (38)
    
end

% Equations (29) - (32), (27), (33), (34)
function trainUV(z)

global Row Col incidenceU kernelU distanceU Utotal T phi k beta da kernelV dv epsilon kernelH;

len = Row * Col;
index = [1, 1; 1, 2; 2, 1; 2, 2]; % (k, r)

A = cell(4);
temp1 = cell(4);
temp2 = cell(4);

Z = cell(2);
Z{1} = spdiags(z(:, 1), 0, len, len);
Z{2} = spdiags(z(:, 2), 0, len, len);

for i = 1 : 4
    
    E = max((distanceU - k * kernelU{i}), 0);
    A{i} = spfun(@(x) (beta ./ (beta + x)), E);

end

for i = 1 : 4
    
    if mod(i, 2) == 0 % r = 2
        temp1{i} = Utotal - sum(kernelU{2} + kernelU{4}, 1);
        temp2{i} = kernelU{i} * spdiags((z(:, 1)' * A{2} + z(:, 2)' * A{4})', 0, len, len) - kernelU{i} .* (Z{index(i, 1)} * A{i});
        
        
    else              % r = 1
        temp1{i} = Utotal - sum(kernelU{1} + kernelU{3}, 1);
        temp2{i} = kernelU{i} * spdiags((z(:, 1)' * A{1} + z(:, 2)' * A{3})', 0, len, len) - kernelU{i} .* (Z{index(i, 1)} * A{i});
        
    end
    
end


for i = 1 : 4
   
    f = z(:, index(i, 2));
    f(f <= T) = 0;
    F = spdiags(f, 0, len, len);
    kernelU{i} = kernelU{i} + da * (Z{index(i, 1)} * A{i} * spdiags(temp1{i}', 0, len, len) - phi * temp2{i}) * F;
    
    %{
    S = (F ~= 0);
    S = sum(sum(S));
    if S ~= 0
        disp(strcat(num2str(i), '->',num2str(S)));
    end
    %}
    
    %B = double(spfun(@(x) (abs(x - 1)), A{i}) < epsilon);
    B = spfun(@(x) max(epsilon - abs(x - 1), 0), A{i});
    B = spones(B);
    kernelV{i} = kernelV{i} + dv * Z{index(i, 1)} * (B .* (kernelU{i} * F) - kernelV{i});
    
    kernelH{i} = kernelU{i} .* kernelV{i};
    
end

% Equations (35), (36)
function trainT(z, s)

global Row Col kernelTplus kernelTminus kernelH tau dw T;

index = [1, 1; 1, 2; 2, 1; 2, 2]; % (k, r)

F = z;
F(F <= T) = 0;

temp1 = kernelH{1} * F(:, 1) + kernelH{2} * F(:, 2);
temp2 = kernelH{3} * F(:, 1) + kernelH{4} * F(:, 2);

for i = 1 : 4
    
    if i == 1 || i == 2
        temp = temp1;
    else
        temp = temp2;
    end
    
    kernelTplus{i} = kernelTplus{i} + dw * s(:, index(i, 2)) .* (tau * temp - kernelTplus{i});
    
    kernelTminus{i} = kernelTminus{i} + dw * s(:, index(i, 2)) .* (s(:, index(i, 1)) - kernelTminus{i});
    
end


% Initialisations and other supporting methods


function initStructs()

global kernelG1 kernelG2 upHorizontal downHorizontal rightVertical leftVertical sigma1 sigma2;

kernelG1 = gaussian(sigma1);
kernelG2 = gaussian(sigma2);
W();
U();
V();
H();
T();
upHorizontal = incidenceHorizontalUp();
downHorizontal = incidenceHorizontalDown();
rightVertical = incidenceVerticalRight();
leftVertical = incidenceVerticalLeft();

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

fileName = fullfile(fileparts(which(mfilename)), 'WKernels', strcat(num2str(Row), '_', num2str(Col), '_', num2str(Wrange), '.mat'));

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

function U()

global Row Col Hrange incidenceU kernelU distanceU;

fileName = fullfile(fileparts(which(mfilename)), 'UKernels', strcat(num2str(Row), '_', num2str(Col), '_', num2str(Hrange), '.mat'));

if exist(fileName, 'file') == 2
    load(fileName, 'incidenceU', 'kernelU', 'distanceU');
    return;
end

a = floor(Row / 2);
b = floor(Col / 2);
len = Row * Col;

I = [1 : Row]' * ones(1, Col);
J = ones(Row, 1) * [1 : Col];
M = sqrt((I - a) .^2 + (J - b) .^2);
M(M >= Hrange / 2) = 0;
distanceU = prepareKernel(a, b, Row, Col, M)';
M = double(M ~= 0);
incidenceU = prepareKernel(a, b, Row, Col, M)';

for i = 1 : 4
    kernelU{i} = sparse(len, len);
end

save(fileName, 'incidenceU', 'kernelU', 'distanceU');

function V()

global Row Col kernelV;

fileName = fullfile(fileparts(which(mfilename)), 'VKernels', strcat(num2str(Row), '_', num2str(Col), '.mat'));

if exist(fileName, 'file') == 2
    load(fileName, 'kernelV');
    return;
end

len = Row * Col;

for i = 1 : 4
    kernelV{i} = sparse(len, len);
end

save(fileName, 'kernelV');

function H()
    
global kernelU kernelV kernelH;
    
for i = 1 : 4
    kernelH{i} = kernelU{i} .* kernelV{i};
end

function T()

global Row Col kernelTplus kernelTminus;

fileName = fullfile(fileparts(which(mfilename)), 'TKernels', strcat(num2str(Row), '_', num2str(Col), '.mat'));

if exist(fileName, 'file') == 2
    load(fileName, 'kernelTplus', 'kernelTminus');
    return;
end

len = Row * Col;

for i = 1 : 4;
    kernelTplus{i} = zeros(len, 1);
    kernelTminus{i} = zeros(len, 1);
end

save(fileName, 'kernelTplus', 'kernelTminus');

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
