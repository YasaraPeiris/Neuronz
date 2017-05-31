function trainModel(layers, dataSize) % Using Oja's rule

global t weights numLayers;

t = 0.001;
trainingRatio = 0.7;
p = 0.3;

initialise(layers);

images = loadTrainImages();
labels = loadTrainLabels();

[~, c] = size(images);
dataSize = min(c, dataSize);

norms = [];

iterations = dataSize;

testLabels = [];
clusters = [];

results = cell(numLayers);
tempW = weights;

trainingSize = floor(double(dataSize) * trainingRatio);
unclassified = 0;

%{
im = vec2mat(images(:, randi(10000)), 28)';
imshow(im);
drawnow;
%}

for r = 1 : iterations
   
    results{1} = normc(mat2gray(images(:, r)));
    
    for k = 1 : numLayers - 1
        
        results{k + 1} = normc(weights{k} * results{k});
        
    end
    
    if(r > trainingSize)
        [m, i] = max(results{numLayers});
        if(m >= p)
            testLabels = [testLabels; labels(r)];
            clusters = [clusters; i];
        else
            unclassified = unclassified + 1;
        end
    end
    
    STDP_update(results);
    
    norms = [norms; zeros(1, numLayers - 1)];
    
    for k = 1 : numLayers - 1
        
        norms(end, k) = norm(weights{k} - tempW{k},'fro') / numel(weights{k});
        tempW{k} = weights{k};
        
    end
    
end

plotPerformance([1 : iterations]', norms, testLabels, clusters);

disp(['Unclassified: ', int2str(unclassified), ' out of ', int2str(dataSize - trainingSize)]);

%disp(clusters);

function initialise(layers)

global weights numLayers;

layers = [784, layers, 10];

[~, numLayers] = size(layers);

weights = cell(numLayers - 1);

for i = 1 : numLayers - 1
    
    %weights{i} = rand(layers(i + 1),layers(i));
    weights{i} = normr(binornd(15, 0.5, layers(i + 1),layers(i)));
    
end


function STDP_update(results)

global t weights numLayers;

%{
tResults = cell(numLayers);

for i = 1 : numLayers
    
    tResults{i} = results{i}';
    
end
%}

temp1 = results{1}'; % temp1 - tranpose of input layer, temp2 - transpose of output layer, to avoid redundant computing

for r = 1 : numLayers - 1
    
    temp2 = results{r + 1}';
    
    [s, ~] = size(results{r + 1});
    
    weights{r} = weights{r} + t * results{r + 1} * (temp1 -  temp2 * weights{r});
    
    %weights{r} = weights{r} + t * (results{r + 1} * results{r}' -  spdiags(results{r + 1} .^2, 0, s, s) * weights{r});
   
    temp1 = temp2;
    
end
