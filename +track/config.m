function opts = config(data_set, exp_id, varargin)
% config file for cell tracking
% details of parameters are given besides their names
% 
% Inputs:
%     data_set : name of the dataset
%     exp_id : experiment id
% 

paths = get_paths();
out_dir = fullfile(paths.save.track, sprintf('%s-E%s', data_set, num2str(exp_id, '%04d')));

ip = inputParser;
% required: experiment related
ip.addParameter('dataset', data_set, @isstr);
ip.addParameter('exp_id',   exp_id, @isscalar);

ip.addParameter('train_seq', [1 2], @ismatrix);% training sequences
ip.addParameter('test_seq',     1, @ismatrix);% testing sequence
ip.addParameter('test',     false, @islogical);% CTC TEST sequences are tracked [1:ONLY then TEST (empty) GT may be loaded]
ip.addParameter('train',    false, @islogical);% CTC TRAIN sequences are tracked: to compute training error

ip.addParameter('whole',        true, @islogical);% process:: 1:whole sequence, 0: only tracked frames
ip.addParameter('quick',        false, @islogical);% skip saving videos for faster execution
ip.addParameter('reuse',        false, @islogical);% to avoid redundent computations when evaluating both sequences
ip.addParameter('redo',         false, @islogical);% deletes everything except prop and starts fresh
ip.addParameter('redo_props',   false, @islogical);% delete ONLY props
ip.addParameter('verbose',      false, @islogical);% prints some info when executing [todo: fix]

% intermediary
ip.addParameter('train_str', {'test', 'train'}, @iscellstr);% to save train/test data
ip.addParameter('set_strs', {'',''}, @iscell);% to pick CTC TEST/TRAIN sets

% save data
ip.addParameter('save_res',     true, @islogical);% save tracking graph and tracks
ip.addParameter('root_data',    paths.save.track, @isstr);
ip.addParameter('out_dir',      out_dir, @isstr);% where tracking results are saved
ip.addParameter('cpn_dir',      paths.save.cpn_res, @isstr);% where cpn proposals are located

% visualization
ip.addParameter('video_errors', false, @islogical);
ip.addParameter('video_tracks', false, @islogical);
ip.addParameter('video_props',  false, @islogical);
ip.addParameter('video_view',   false, @islogical);

% proposals
ip.addParameter('proposal', 'cpn', @isstr);% what proposals to use: 'cpn' or 'blob'
ip.addParameter('prop_fun', @(w,d,s) sprintf(''), @(x) isa(x,'function_handle'));% 
ip.addParameter('cpn_thresh',           0.1, @isscalar);% remove proposals with lower score
ip.addParameter('conflict_iou',         0.2, @isscalar);% .3
ip.addParameter('conflict_int_thresh',  0.6, @isscalar);%.6 if A & B satisfy "intersect(A,B)/|A| > this" OR "intersect(A,B)/|B| > this" then only 1 can be selected. : has little impact on performance
ip.addParameter('min_size',             50, @isscalar);% min cell size
ip.addParameter('max_size',             3000, @isscalar);% max cell size

% BLOB ONLY
ip.addParameter('prune',            0, @isscalar);
ip.addParameter('overlap_thresh', 0.95, @isscalar);

% tracking
ip.addParameter('specific',     2, @isscalar);% 0: same settings, 1: use few data specific settings, 2: use more data specific settings
ip.addParameter('solver',       'ilp', @islogical);
ip.addParameter('feature_set', 'celldetect', @isstr);% what feature set to use: 'cpn' or 'CellDetect'
ip.addParameter('max_move', 30, @isscalar);% gating threshold
ip.addParameter('move_sampling', 1, @isscalar);%1: allow moves to all proposals within a fixed radius, 3: balanced [nearby props are prioritized]
ip.addParameter('mitosis_pairs', 4, @isscalar);% pais of mitosis daughters

% enable/disable tracking graph component
ip.addParameter('use_move',     true, @islogical);
ip.addParameter('use_mitosis',  false, @islogical);
ip.addParameter('use_apoptosis', false, @islogical);
ip.addParameter('use_enter',    true, @islogical);
ip.addParameter('use_exit',     true, @islogical);

ip.addParameter('score_transform', '', @isstr);
ip.addParameter('out_type',     2, @isscalar);%1: classifier, 2:fixed cost, 3: distance from border based
ip.addParameter('p_enter',      -1, @isscalar);% -1: get from GT
ip.addParameter('p_exit',       -1, @isscalar);% -1: get from GT

% ilp parameters
ip.addParameter('ilp_solver', 'gurobi', @isstr);% which ilp solver to use: 'gurobi' OR 'matlab' [todo: broken]

% sp parameters
ip.addParameter('sp_solver',        2, @isscalar);% which sp solver to use: todo: broken
ip.addParameter('sp_props',         1, @isscalar);% 1: proposals, 0: segmentations
ip.addParameter('sp_cost_thresh',   0, @isscalar);% terminate when cost of a track is higher than this

% post-processing
ip.addParameter('post_dilate',  0, @isscalar);% dilate tracked masks: used for better matching with gt markers. [u373 & psc] datasets have some markers v close to cell boundaries
ip.addParameter('post_mitosis', 0, @isscalar);% detect missed mitosis after tracking
ip.addParameter('post_rm_border', true, @islogical);% remove cells outside field of interest

% internal
ip.addParameter('compute_score', true, @islogical);% compute score of the selected tracks [todo: broken]
%
ip.parse(varargin{:});
opts = ip.Results;

if opts.quick
    opts = bia.utils.setfields(opts,'video_errors',0,'video_tracks',0,'video_props',0);
end
if opts.reuse
    opts.train_str = {'train', 'train'};% reuse data extracted during training for testing
end

[opts.file, opts.fun] = get_paths_local(opts.out_dir, opts.dataset);
fun_video = @(s,x) fullfile(opts.out_dir, sprintf('%s-%04d_%s-%02d', s, opts.exp_id, opts.dataset, x));

opts.opts_move = struct('trees',100,'norm_type',0,'verbose',opts.verbose);
opts.opts_mitosis = struct('trees',100,'norm_type',0,'verbose',opts.verbose);
opts.opts_enter = struct('verbose',opts.verbose);
opts.opts_exit = opts.opts_enter;




opts.opts_props = struct('mode',1,'border_thickness',1,'alpha',.75,'use_sqrt',0,...
    'save_path_fun',@(x) fun_video('props',x));
opts.opts_video = struct('verbose',0, 'rect', [],'mode',3,'use_sqrt',0,'show_im',0,...
    'save_path_fun', @(x) fun_video('tracks',x),...
    'opts_traj', struct('traj_len',[20 0],'line_width',2,'alpha',1), ...
    'opts_boundary', struct('border_thickness',1,'alpha',1));

if contains(opts.dataset, {'Fluo-N2DL-HeLa';'Fluo-N2DH-GOWT1'})
    opts.opts_video.use_sqrt = 1;
    opts.opts_props.use_sqrt = 1;
end


if opts.train && opts.test
    opts.set_strs = {'Train-00','Train-00'};% train error for both TRAIN seqs
elseif opts.train
    opts.set_strs = {'Train-','Train-'};% train on ind TRAIN sequences
elseif opts.test
    opts.set_strs = {'00','Train-00'};
end

% assert(opts.test + opts.train <= 1, 'TEST Set can''t be selected when computing training error')
end


function [file, fun] = get_paths_local(out_dir, data_set)
% sets all paths of all files where data will be saved
bia.save.mkdir(out_dir)
% file paths
file.diary        = fullfile(out_dir, sprintf('%s.log', datetime('now','TimeZone','local','Format','yyyy-MM-dd_HH.mm.ss')));
fun.props         = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-proposals.mat', w, x, data_set));
fun.conflicts     = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-conflicts.mat', w, x, data_set));
fun.feats         = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-feats.mat', w, x, data_set));
fun.cell_model    = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-cell_model.mat', w, x, data_set));
fun.move_feats    = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-feats_move.mat', w, x, data_set));
fun.move_model    = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-prob_move.mat', w, x, data_set));
fun.enter_exit_feats = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-feats_enter_exit.mat', w, x, data_set));
fun.enter_model   = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-prob_enter.mat', w, x, data_set));
fun.exit_model    = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-prob_exit.mat', w, x, data_set));
fun.mitosis_feats = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-feats_mitosis.mat', w, x, data_set));
fun.mitosis_model = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-prob_mitosis.mat', w, x, data_set));
fun.tracks        = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-tracks.mat', w, x, data_set));
fun.graph         = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-graph.mat', w, x, data_set));
fun.packed        = @(w,x) fullfile(out_dir, sprintf('%s-%02d-%s-packed.mat', w, x, data_set));
end