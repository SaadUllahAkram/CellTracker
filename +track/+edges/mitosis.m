function [edges, labels, errors] = mitosis(opts, stats, gt, ims)
% stats must be compact

% marks the edges which need to be enabled for mitosis detection
% todo: be careful with multiple proposals which may create redundent proposals

% colors:: mitosis:: r: GT parent, g: GT daughter, b: all GT
% colors:: enter/exit:: r: GT cell enter/leave, g: all GT

opts_default = struct('max_move',0,'mitosis_pairs',1,'do_plot',0,'verbose',0,'seq',0,'root','','plot_debug',0,'plot_errors',0);
opts      = bia.utils.updatefields(opts_default, opts);
max_dist  = opts.max_move;%30;
max_pairs = opts.mitosis_pairs;
verbose   = opts.verbose;
s         = opts.seq;
root      = opts.root;
plot_debug= opts.plot_debug;
plot_errors= opts.plot_errors;

sz = gt.sz;
T = gt.T;
if isfield(gt, 'tra')
    gt_info = gt.tra.info;
    gt_stats= gt.tra.stats;
    t_tracked = gt.tra.tracked;
else
    gt_info = [];
    gt_stats= cell(T,1);
    t_tracked = zeros(1,T);
end

if plot_debug
    root = fullfile(root, sprintf('%02d', s));
    bia.save.mkdir(root)
end
parents_id = bia.track.events([],gt_info);


matches = cell(T,1);
cents = cell(T,1);
parfor t=1:T
   matches{t} = bia.utils.match(struct('max_match',1), gt_stats{t}, stats{t}, sz(t,1:2));
   cents{t} = bia.convert.centroids(stats{t});
end

gt_edges = get_gt_mitosis_edges(gt_info, verbose);%[t_par, id_par, t_dau, id_dau, id_mit]
gt_edges(:,6) = 0;% track type of error: 2->found both parent&daus, 1->found just parent, 0->found none

if plot_debug
    [hfig1,ax1] = bia.plot.fig('Parent',[1 2]);
    [hfig2,ax2] = bia.plot.fig('Daughters',[1 2]);
    drawnow
end
% [pt pid dt did i covered]
if plot_debug
    parents = unique(gt_edges(:,5))';
    parents(1:45) = [];
    for i=parents
        fprintf('%d ', find(parents == i, 1))
        e = gt_edges(gt_edges(:,5)==i,:);
        t = e(1,1);
        t_next = e(1,3);
        parent_id = e(1,2);
        dau_id = e(:,4);
        im = ims{t};
        sz = size(im);
        imn = ims{t_next};
        stats_res = stats{t};
        stats_resn = stats{t_next};
        stats_gt = gt_stats{t};
        stats_gtn = gt_stats{t_next};

        r = bia.convert.rect(struct('pad',20,'sz',sz), [stats_gt(parent_id); stats_gtn(dau_id)]);

        cla(ax1(1))
        cla(ax1(2))
        imshow(im,'parent',ax1(1))
        bia.plot.centroids(ax1(1), stats_gt(parent_id))
        imshow(bia.draw.boundary(struct('alpha',.5),im, stats_res),'parent',ax1(2))
        axis(ax1(1), r([3 4 1 2]))
        axis(ax1(2), r([3 4 1 2]))

        cla(ax2(1))
        cla(ax2(2))
        imshow(imn,'parent',ax2(1))
        bia.plot.centroids(ax2(1), stats_gtn(dau_id))
        imshow(bia.draw.boundary(struct('alpha',.5),imn, stats_resn),'parent',ax2(2))
        axis(ax2(1), r([3 4 1 2]))
        axis(ax2(2), r([3 4 1 2]))
        if ~isempty(root)
            cap1 = bia.save.getframe(hfig1);
            cap2 = bia.save.getframe(hfig2);
            cap = cat(2, cap1, cap2);
            imwrite(cap,fullfile(root, sprintf('%s-%02d-t%03did%04d_mitosis.png',gt.name, s, t, parent_id)))%todo: gt.name does not exist for test data
        end
        drawnow
    end
    fprintf('\n')
end
edges = cell(T-1,1);
labels = cell(T-1,1);
for t = 1:T-1
    cents_t = cents{t};
    match_t = matches{t};
    cents_n = cents{t+1};
    match_n = matches{t+1};
    
    gt_edges_t = gt_edges(gt_edges(:,1)==t,:);%[t_par, id_par, t_dau, id_dau, id_mit]
    dist_t2n = pdist2(cents_t, cents_n);% dist moved to move from a prop @t to @t+1
    n_daughters_t = size(gt_edges_t,1);

    edges_t = zeros(0,5);
    labels_t = zeros(0,1);
    for i=1:size(cents_t,1)% loop over all detections in current frame
        gt_t = find(match_t(:,i), 1);
        if isempty(gt_t)
            gt_t = 0;
        elseif ~ismember(gt_t, gt_edges_t(:,2))% is not one of parents
            gt_t = 0;
        end
        neighbors = get_neighbors(dist_t2n(i,:), max_pairs, max_dist);
        edges_t_i = get_edge_pairs(neighbors, t, i);%[t par dau1 dau2]
        
        E = size(edges_t_i,1);
        label = zeros(E,1);
        if gt_t ~= 0
            gt_edges(gt_edges(:,1)==t & gt_edges(:,2)==gt_t, 6) = 1;
            gt_daus = gt_edges_t(gt_edges_t(:,2) == gt_t, 4);
            [label, gt_daus_found] = get_label(edges_t_i, gt_daus, match_n);
            if sum(label) > 0
                gt_edges(gt_edges(:,1)==t & gt_edges(:,2)==gt_t & ismember(gt_edges(:,4), gt_daus_found) , 6) = 2;
            end
        end
        if (~t_tracked(t) || ~t_tracked(t+1))
            assert(sum(label) == 0)
            label = -ones(E,1);
        end
        edges_t = [edges_t; edges_t_i];
        labels_t = [labels_t; label];
    end
    
    edges{t} = edges_t;
    labels{t} = labels_t;
end
edges = cell2mat(edges);
labels = cell2mat(labels);
% convert ids to unique ids
[~,map] = bia.convert.id(stats);
edges(:,2) = bia.convert.id(edges(:,[1,2]), map);
edges(:,3) = bia.convert.id([1+edges(:,1), edges(:,3)], map);
edges(:,4) = bia.convert.id([1+edges(:,1), edges(:,4)], map);
edges(:,1) = [];

errors.fn = [gt_edges(gt_edges(:,6)==0,:);...%parent not matched
    gt_edges(gt_edges(:,6)==1,:)];%daughters not matched
counts = struct('fn_parent', sum(gt_edges(:,6)==0),...
    'fn_daughters', sum(gt_edges(:,6)==1),...
    'tp', sum(gt_edges(:,6)==2));
if verbose
    fprintf('#Mitosis:(Parents:%d->Daughter:%d), #EdgeProposals:%d, TP:%d, FN-Par:%d, FN-Dau:%d\n',length(parents_id),size(gt_edges,1), size(edges,1),...
        counts.tp, counts.fn_parent, counts.fn_daughters)
end

if plot_errors
    if ~isempty(errors.fn)
        [~,hax] = bia.plot.fig('Mitosis errors', [1 2], 0, 0);
        plot_error(hax, errors.fn, stats, ims, gt_stats);
    end
end
end


function plot_error(hax, edges, stats, ims, gt_stats)
for i=1:size(edges,1)
    t = edges(i,1);
    tn= edges(i,3);
    p_id = edges(i,2);
    d_id = edges(i,4);
    ot = bia.utils.overlap_pixels(gt_stats{t}, stats{t});
    otn= bia.utils.overlap_pixels(gt_stats{tn}, stats{tn});
    idxt = ot(p_id,:)'>0;
    idxtn= otn(d_id,:)'>0;
    r1 = bia.convert.rect(struct('pad',0), [gt_stats{t}(p_id); gt_stats{tn}(d_id)]);
    r2 = bia.convert.rect(struct('pad',0), [stats{t}(idxt); stats{tn}(idxtn)]);
    r = bia.convert.rect(struct('pad',25), [r1;r2]);
    im= bia.draw.boundary([],ims{t},stats{t});
    imshow(im,'parent',hax(1));
    bia.plot.centroids(hax(1),gt_stats{t},'g')
    bia.plot.centroids(hax(1),gt_stats{t}(p_id))
    axis(hax(1), r([3 4 1 2]))
    imn= bia.draw.boundary([],ims{tn},stats{tn});
    imshow(imn,'parent',hax(2));
    bia.plot.centroids(hax(2),gt_stats{tn},'g')
    bia.plot.centroids(hax(2),gt_stats{tn}(d_id))
    axis(hax(2), r([3 4 1 2]))
end
end


function edges = get_gt_mitosis_edges(info, verbose)
% edges : [t_parent, id_parent, t_daughter, id_daughter, mitosis_id]
[parents_id, parents_t] = bia.track.events([], info);
edges = zeros(0,6);
for i=1:length(parents_id)
    pid = parents_id(i);
    pt = parents_t(i);
    daus = info(info(:,4) == pid);
    for j=1:length(daus)
        did = daus(j);
        dt = info(info(:,1)==did, 2);
        if dt ~= pt+1;  covered = 0;
        else;   covered = 1;
        end
        edges = [edges; [pt pid dt did i covered]];
    end
end
if verbose; fprintf('GT Daughters which skip frames: %d\n', sum(edges(:,6) == 0));  end
end


function [neighbors, dists] = get_neighbors(dist, max_pairs, max_dist)
for i=1:max_pairs
    [dists(i), neighbors(i)] = min(dist);
    dist(neighbors(i)) = Inf;
end
neighbors(dists > max_dist) = [];
dists(dists > max_dist) = [];
end

function edges = get_edge_pairs(neighbors, t, id_parent)
edges = zeros(0,5);%[t par dau1 dau2]
k = 0;
for i=1:length(neighbors)
    for j=i+1:length(neighbors)
        k = k+1;
        edges = [edges; t id_parent neighbors(i) neighbors(j) k];
    end
end
end


function [labels, gt_daus_found] = get_label(edges_t, gt_daus, match_n)
E = size(edges_t, 1);
gt_daus_found = [];
labels = zeros(E,1);
for k=1:E
    res_id = edges_t(k,3:4);
    d1 = find(match_n(:, res_id(1)));
    d2 = find(match_n(:, res_id(2)));
    if length(d1) == 1 && length(d2) == 1
        if d1 ~= d2 && ismember(d1, gt_daus) && ismember(d2, gt_daus)
            labels(k) = 1;
            gt_daus_found = [d1, d2];
        end
    end
end
end
