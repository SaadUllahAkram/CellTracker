function [test_feats, test_labs, train_feats, train_labs] = feats_mitosis(edges, labels, stats, sz)

train_feats = extract_feats(stats, edges, sz);
train_labs = [labels; labels];

test_feats = train_feats(1:size(train_feats,1)/2,:);
test_labs = labels;
end


function f = extract_feats(stats, edges_in, sz)
E = size(edges_in,1);
if isempty(edges_in)
   f = zeros(0,5);
   return
end

[~,map] = bia.convert.id(stats);
edges = bia.convert.id(edges_in(:,1), map);
tmp = bia.convert.id(edges_in(:,2), map);
edges(:,3) = tmp(:,2);
tmp = bia.convert.id(edges_in(:,3), map);
edges(:,4) = tmp(:,2);

for t=1:length(stats)
    PixelIdxList = cell(length(stats{t}), 1);
    for k=1:length(stats{t})
        PixelIdxList{k} = stats{t}(k).PixelIdxList;
    end
    CC = struct('Connectivity', 8, 'NumObjects', length(stats{t}), 'ImageSize', sz(t,1:2), 'PixelIdxList', {PixelIdxList});
    stats2 = regionprops(CC, 'Eccentricity');
    stats{t} = bia.utils.catstruct(stats{t}, stats2);
end

tmp = extract_feat(stats, edges(1,1), edges(1,2), edges(1,3:4), sz);
N = length(tmp);
f1 = zeros(E, N);
f2 = zeros(E, N);
parfor i=1:E
    [f1(i,:), f2(i,:)] = extract_feat(stats, edges(i,1), edges(i,2), edges(i,3:4), sz);
end
% f = f1;
f = [f1;f2];
end


function [f1, f2] = extract_feat(stats, t, pid, dids, sz)
% add features based on nearest neighbor (maybe how many cells are within r radius) in previous frame
% add feature counting other cell which are closer to daughter than parent in t-1
% add constraint that the two daughters do not conflict
p = stats{t}(pid);
d1= stats{t+1}(dids(1));
d2= stats{t+1}(dids(2));

% find the min distance between border of daughters
odd  = bia.utils.iou_mex(d1.PixelIdxList, d2.PixelIdxList);% overlap of daughter props: may help to prevent daughters which have large overlap with each other
opd1 = bia.utils.iou_mex(d1.PixelIdxList, p.PixelIdxList);
opd2 = bia.utils.iou_mex(d2.PixelIdxList, p.PixelIdxList);
cdd  = bia.utils.iou_centered(d1, d2, sz(t,:));
cpd1 = bia.utils.iou_centered(p, d1, sz(t,:));
cpd2 = bia.utils.iou_centered(p, d2, sz(t,:));

% a=f_pos(:,3)-(f_pos(:,1)+f_pos(:,2));
dp1 = dist(p.Centroid, d1.Centroid);
dp2 = dist(p.Centroid, d2.Centroid);
d12 = dist(d1.Centroid, d2.Centroid);

dy = d2.Centroid(2) - d1.Centroid(2);
dx = d2.Centroid(1) - d1.Centroid(1);
if dx == 0; dx=eps;end
m = dy/dx;
num = sqrt(sum([m, -1].^2));
if num == 0; num=eps;end
c = d2.Centroid(2) - m*d2.Centroid(1);
sd = abs(m*p.Centroid(1) + -1*p.Centroid(2) + c)/num;% shortest dist of parent from line joining daughters

f1 = [dp1, dp2, d12, opd1, opd2, odd, cpd1, cpd2, cdd, p.Features, d1.Features, d2.Features, bia.ml.feats_ratio(d1.Features, d2.Features), sd, p.Score, d1.Score, d2.Score];
f2 = [dp2, dp1, d12, opd2, opd1, odd, cpd2, cpd1, cdd, p.Features, d1.Features, d2.Features, bia.ml.feats_ratio(d2.Features, d1.Features), sd, p.Score, d2.Score, d1.Score];


f1 = [abs(f1(3) - (f1(1)+f1(2))), f1];
f2 = [abs(f2(3) - (f2(1)+f2(2))), f2];
end


function d = dist(c1, c2)
d = abs(c1-c2);
d = sqrt(sum(d.^2));
end
