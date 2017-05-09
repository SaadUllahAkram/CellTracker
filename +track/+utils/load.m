function data = load(opts, s, train)
% loads: gt, proposals, images
% computes: features, conflicts
% 

dataset = opts.dataset;
min_size= opts.min_size;
max_size= opts.max_size;
cpn_thresh= opts.cpn_thresh;

file_props = opts.fun.props(opts.train_str{train+1}, s);
file_conflicts = opts.fun.conflicts(opts.train_str{train+1}, s);
file_feats = opts.fun.feats(opts.train_str{train+1}, s);

[gt, ims] = bia.datasets.load(sprintf('%s-%02d', dataset, s),{'gt','im'},struct('tracked',~opts.whole,'test',opts.test==1 && opts.train==0 && train==0));
if ( opts.p_enter == -1 || opts.p_exit == -1 ) && train
    tmp = bia.datasets.stats(struct('verbose',0),gt);
    p_enter = tmp.n_enter/tmp.n_move_edges + 0.001;
    p_exit = tmp.n_exit/tmp.n_move_edges + 0.001;
    %fprintf('%1.5f, %1.5f\n', p_enter, p_exit)
else
    p_enter = opts.p_enter;
    p_exit = opts.p_exit;
end

T = length(ims);
if ~exist(file_props, 'file')
    if strcmp(opts.proposal, 'cpn')
        %fprintf('%s', opts.cpn_fun(opts.set_strs{train+1}, dataset, s))
        cspn_data = load(opts.cpn_fun(opts.set_strs{train+1}, dataset, s));
        stats = filter_low_scores(cspn_data.stats, cpn_thresh);
        clear cspn_data
    elseif strcmp(opts.proposal, 'blob')
        stats = proposal.propos_blob(opts, ims);
    end
    % remove small/big regions
    for t=1:T
        stats{t} = bia.utils.bwareaopen(stats{t}, [min_size max_size]);
        stats{t} = bia.struct.standardize(stats{t},'seg');
    end
    save(file_props, 'stats')
else
    load(file_props, 'stats')
end

if opts.whole
    assert(length(stats) == gt.T)
elseif length(stats) > gt.T
    gt_tmp = bia.datasets.load(sprintf('%s-%02d', dataset, s));
    stats = stats(gt_tmp.tra.tracked==1,1);% remove untracked frames
    clear gt_tmp
end

if strcmp(opts.feature_set, 'cpn')
    stats = bia.ml.region_labels(struct('max_labels', 1), stats, gt.detect, size(ims{1}));
elseif strcmp(opts.feature_set, 'celldetect')
    stats = add_features(stats, ims, gt, file_feats, opts.feature_set, 1);
end

if exist(file_conflicts, 'file')
    load(file_conflicts, 'constraints', 'conflicts', 'weights')
else
    conflicts = cell(T,1);
    constraints = cell(T,1);
    weights = cell(T,1);
    for t=1:T
        [constraints{t}, conflicts{t}, weights{t}] = bia.utils.conflicts(struct('conflict_int_thresh',opts.conflict_int_thresh,'conflict_iou',opts.conflict_iou), stats{t});
    end
    save(file_conflicts, 'constraints', 'conflicts', 'weights')
end

data = struct('gt',gt,'ims',{ims},'stats',{stats},'conflicts',{conflicts},'constraints',{constraints},'weights',{weights},...
    'train',train,'dataset',dataset,'seq',s,'p_enter',p_enter,'p_exit',p_exit);
end


function cspn_stats = filter_low_scores(cspn_stats, cpn_thresh)
% remove low scored proposals
parfor t=1:length(cspn_stats)
    cspn_stats{t} = cspn_stats{t}([cspn_stats{t}.Score] > cpn_thresh);
    cspn_stats{t} = bia.struct.standardize(cspn_stats{t},'seg');
end
end


function stats = add_features(stats, ims, gt, file, feature_set, max_labels)
% extract features
T = length(stats);
if exist(file, 'file')
    load(file, 'feats')
    for t=1:T
        stats{t} = bia.utils.catstruct(stats{t}, feats{t});
    end
else
    if isempty(gt) || ~isfield(gt, 'detect')
        gt.detect = [];
    end
    stats = bia.feats.extract(struct('feature_set', feature_set), stats, ims);
    stats = bia.ml.region_labels(struct('max_labels', max_labels), stats, gt.detect, gt.sz);

    rm_fields = setdiff(fieldnames(stats{1}), {'Features', 'Label'});
    feats = cell(T,1);
    for t=1:T
        feats{t} = rmfield(stats{t}, rm_fields);
    end
    save(file, 'feats')
end
end