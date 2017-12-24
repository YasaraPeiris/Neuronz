function predict(layerset, dataSize)

global weights numLayers layers;

layers = [784, layerset, 10];
[~, numLayers] = size(layers);

images = loadTrainImages();
labels = loadTrainLabels();

selected = find(labels == 5 | labels == 1);
labels = labels(selected);
images = images(:, selected);

[~, c] = size(images);
dataSize = min(c, dataSize);

iterations = dataSize;

testLabels = [];
clusters = [];

results = cell(numLayers);

loadWeights();
p = 0.3;

unclassified = 0;

for r = 1 : iterations
   
    results{1} = normc(mat2gray(images(:, r)));
    
    %results{1} = sigmf(mat2gray(images(:, r)), [5.0 0.5]);
    
    for k = 1 : numLayers - 1
        
        results{k + 1} = normc(weights{k} * results{k});
        
        %results{k + 1} = sigmf(weights{k} * results{k}, [5.0 0.5]);
        
    end
    
    [m, i] = max(results{numLayers});
    if(m >= p)
        testLabels = [testLabels; labels(r)];
        clusters = [clusters; i];
    else
        unclassified = unclassified + 1;
    end

    %{
    temp = [temp, [results{numLayers} ; ones(3, 1)]];
    c = c + 1;

    if mod(c, 100) == 0
        disp(c);
        picMap = [picMap ; temp];
        temp = [];
        c = 0;
    end
    %}    
    
end

plotPerformance([1 : iterations]', [], testLabels, clusters, [2, 3]);

disp(['Unclassified: ', int2str(unclassified), ' out of ', int2str(dataSize)]);


function loadWeights()

global weights layers;

fileName = sprintf('%d_', layers);
fileName = strcat(fileName(1 : end - 1), '.mat');
fileName = fullfile(fileparts(which(mfilename)), '..\WeightDatabase\Temp', fileName);

if exist(fileName, 'file') == 2
    load(fileName, 'weights');
else
    disp('Trained network not available');
    exit;
end