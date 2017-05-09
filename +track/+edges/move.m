function [edges, labels, feats, errors] = move(opts, stats, gt)
% feats: features
% labels: [id1 id2 label]
% 
opts_defaults = struct('max_move',30,'use_cents',1,'mode',1,'verbose',0);
opts = bia.utils.updatefields(opts_defaults, opts);
mode = opts.mode;
max_move = opts.max_move;
use_cents = opts.use_cents;% 1: use cents to match res & gt, 0: use marker blob
verbose = opts.verbose;

T = length(stats);
if isfield(gt, 'tra')
    gt_stats = gt.tra.stats;
    gt_edges = get_gt_move_edges(gt.tra.stats);
    t_tracked = gt.tra.tracked;
    gt_edges(:,4) = 0;
else
    gt_stats = cell(T,1);
    t_tracked = zeros(1,T);
    gt_edges = zeros(0,4);
end

sz = gt.sz;

offset = cumsum([0; arrayfun(@(x) length(x{1}), stats)]);
feats  = cell(T-1,1);
labels = cell(T-1,1);

matches = cell(T,1);
cents = cell(T,1);
idx_cents = cell(T,1);
g2ds = cell(T,1);
d2gs = cell(T,1);
ious = cell(T,1);
for t=1:T
    [cents{t}, idx_cents{t}] = bia.convert.centroids(stats{t});
    if t_tracked(t)
        matches{t} = bia.utils.match([], gt_stats{t}, stats{t}, sz(t,1:2));
        [~,~,g2ds{t},d2gs{t},~,~,ious{t}] = bia.utils.match_markers(gt_stats{t}, stats{t});
    else
        g2ds{t} = [];
    end
end

idx = cell(T,1);
if ismember(mode, [1 2])% allow moves to all cells within a fixed radius
    for t=1:T-1
        feats{t} = [];
        labels{t} = [];
        idx{t} = [];
    end
    for t=1:T-1
        gt_t = 0;
        gt_n = 0;
        cents_t = cents{t};
        cents_n = cents{t+1};
        
        if t_tracked(t) && t_tracked(t+1)
            match_t = matches{t};
            match_n = matches{t+1};

            iou_t = ious{t};
            g2d_n = g2ds{t+1};
        else
            match_t = zeros(1, size(cents_t,1));
            match_n = zeros(1, size(cents_n,1));
            iou_t = zeros(1, size(cents_t,1));
            g2d_n = cell(0);
        end
        
        dist_t2n = pdist2(cents_t, cents_n);% dist moved to move from a prop @t to @n
        for i=1:size(cents_t,1)% loop over all detections in current frame
            stat_t = stats{t}(i);
            
            if mode == 1
                if sum(match_t(:,i)) == 1;  gt_t = find(match_t(:,i));
                else;   gt_t = 0;
                end
            elseif mode == 2
                [val, gt_t] = max(iou_t(:,i));
                if val == 0
                    gt_t = 0;
                end
            end
            
            close_n = find(dist_t2n(i,:) < max_move);
            for j = close_n% loop over all detections in next frames to which a cell can move
                stat_n = stats{t+1}(j);
                
                if mode == 1
                    if sum(match_n(:,j)) == 1;  gt_n = find(match_n(:,j));
                    else;   gt_n = 0;
                    end
                elseif mode == 2
                    if gt_t > length(g2d_n) || gt_t == 0
                        gt_n = 0;
                    else
                        matched_res_n = g2d_n{gt_t};
                        if isempty(matched_res_n)
                            gt_n = 0;
                        elseif ismember(j, matched_res_n)
                            gt_n = gt_t;
                        else
                            gt_n = 0;
                        end
                    end
                end
                
                if gt_t ~= 0 && gt_n == gt_t;    label=1;
                else;   label=0;
                end
                if label == 1
                    idx{t} = [idx{t}; find(gt_edges(:,1)==t & gt_edges(:,2)==gt_n)];
                end
                if (~t_tracked(t) || ~t_tracked(t+1))
                    label = -1;
                end
                feats{t}(end+1,:) = move_feats(dist_t2n(i, j), stat_t, stat_n, sz(t,1:2));% features
                labels{t}(end+1,:)= [offset(t)+i, offset(t+1)+j, label];% [id1 id2 label]
            end
        end
    end
    for t=1:T-1
       gt_edges(idx{t}, 4) = 1;
    end
elseif ismember(mode, 3)% randomly picks 1 neg move sample, for each pos move sample
    for t=1:T-1
        feats{t}   = [];
        labels{t}  = [];
        
        g2d_t = g2ds{t};
        iou_t = ious{t};

        g2d_n = g2ds{t+1};
        d2g_n = d2gs{t+1};
        iou_n = ious{t+1};

        idx_t = idx_cents{t};
        idx_n = idx_cents{t+1};
        
        active_gt_ids = active_idx(g2d_t, g2d_n);
        dist_t2n = pdist2(cents{t}, cents{t+1});
        for gt_id = active_gt_ids% idx of track
            [~,props_id_t] = max(iou_t(gt_id,:));
            if isempty(props_id_t);   continue;   end
            [~,props_id_n] = max(iou_n(gt_id,:));
            if isempty(props_id_n);  continue;   end
            prop_idx_t = find(idx_t == props_id_t);
            prop_idx_n = find(idx_n == props_id_n);
            stat_t = stats{t}(prop_idx_t);
            stat_n_pos = stats{t+1}(prop_idx_n);

            assert(prop_idx_t == props_id_t)
            assert(prop_idx_n == props_id_n)
            
            dist_pos = dist_t2n(prop_idx_t, prop_idx_n);
            % +ve sample
            feats{t}(end+1, :) = move_feats(dist_pos, stat_t, stat_n_pos, sz(t,1:2));
            if (~t_tracked(t) || ~t_tracked(t+1))
                labels{t}(end+1,:) = [offset(t)+prop_idx_t, offset(t+1)+prop_idx_n, -1];
            else
                labels{t}(end+1,:) = [offset(t)+prop_idx_t, offset(t+1)+prop_idx_n, 1];
            end
            
            % -ve sample
            close_n = find(dist_t2n(prop_idx_t,:) < max_move);% find nearby props
            gt_matched_n = d2g_n(close_n);
            pos_n = arrayfun(@(x) ismember(gt_id, x{1}), gt_matched_n);%find prop ids which contain marker of current gt at next frame
            close_n(pos_n) = [];
            gt_matched_n(pos_n)= [];
            if ~isempty(close_n)
                close_n = close_n(randperm(length(close_n), 1));
                stat_n_neg = stats{t+1}(close_n);
                dist_neg = dist_t2n(prop_idx_t, close_n);
                feats{t}(end+1, :) = move_feats(dist_neg, stat_t, stat_n_neg, sz(t,1:2));
                if (~t_tracked(t) || ~t_tracked(t+1))
                    labels{t}(end+1,:) = [offset(t)+prop_idx_t, offset(t+1)+prop_idx_n, -1];
                else
                    labels{t}(end+1,:) = [offset(t)+prop_idx_t, offset(t+1)+close_n, 0];
                end
            end
        end
    end
end
% fprintf('\n')
feats = cell2mat(feats);
labels = cell2mat(labels);
edges = labels(:,1:2);
labels = labels(:,3);
n_pos = sum(labels(:,end)==1);
n_neg = sum(labels(:,end)==0);
n_props = offset(end);
errors.fn = gt_edges(gt_edges(:,4)==0,:);
if verbose
    fprintf('Edges:(TP:%d, FN:%d), Ratio(Pos/Neg):%1.3f, Pos:%d, Neg:%d, Samples/Prop:%1.3f\n', sum(gt_edges(:,4) == 1), sum(gt_edges(:,4) == 0), n_pos/n_neg, n_pos, n_neg, (n_pos+n_neg)/n_props)
end
end


function feats = move_feats(dist, s1, s2, sz)
iou   = bia.utils.iou_mex(s1.PixelIdxList, s2.PixelIdxList);
iou_c = bia.utils.iou_centered(s1, s2, sz);
% feats = [dist, iou, iou_c, abs(s1.Area-s2.Area)/max(s1.Area,s2.Area), bia.ml.feats_ratio(s1.Features,s2.Features), s1.Score, s2.Score];
feats = [dist, iou, iou_c, abs(s1.Area-s2.Area)/max(s1.Area,s2.Area), bia.ml.feats_ratio(s1.Features,s2.Features), s1.Features, s2.Features, s1.Score, s2.Score];%
end


function edges = get_gt_move_edges(stats)
T = length(stats);
edges = cell(T-1,1);
for t=1:T-1
    edges{t} = zeros(0,3);
    i1 = find([stats{t}.Area]>0);
    i2 = find([stats{t+1}.Area]>0);
    
    i1 = intersect(i1,i2);
    for i=i1
        edges{t} = [edges{t}; t i i];
    end
end
edges = cell2mat(edges);
end


function active_gt_ids = active_idx(g2d, g2d_n)
active          = arrayfun(@(x) ~isempty(x{1}), g2d);
active_next     = arrayfun(@(x) ~isempty(x{1}), g2d_n);
len             = min(length(active), length(active_next));
active_gts      = active(1:len) & active_next(1:len);% gt ids which have a matching proposal in both frames
active_gt_ids   = find(active_gts)';
end
