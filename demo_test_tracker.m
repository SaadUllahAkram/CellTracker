% demo for training cpn and performing cell tracking
bia.caffe.clear;

dataset = 'Fluo-N2DL-HeLa';
exp_id = 1;

bia.add_code({'gurobi'});
bia.compile()
cpn.build()
% bia.caffe.activate('cpn',-1)

paths = get_paths();
root_train = paths.save.cpn;
root_export = paths.save.cpn_res;

% import and preprocess data
bia.datasets.import.ctc(dataset);
bia.datasets.import.ctc_fluo_hela_aug();% hela augmented data using watershed

% train cpn models
for train_seq = 1:2
    opts_cpn = cpn.config('dataset', dataset, 'train_seq', train_seq, 'dont_train', false, 'root_train', root_train, 'root_export', root_export);
    conf_bb  = cpn.bb.config (dataset, train_seq, 1, exp_id,'gt_version',1,'im_version',0,'scale',1, 'root_train', root_train);
    conf_seg = cpn.seg.config(dataset, train_seq, 2, exp_id,'gt_version',0,'im_version',0,'scale',1, 'root_train', root_train);
    cpn.train(opts_cpn, conf_bb, conf_seg);
end
bia.caffe.clear;

% train tracking models
for train_seq = 1:2
    test_seq = 2*(train_seq==1) + 1*(train_seq==2);
    opts_tra = track.config(dataset, exp_id, 'train_seq', train_seq, 'test_seq', test_seq, 'use_mitosis', true,...
        'video_tracks', true);
    opts_tra.cpn_fun = @(w,x,y) fullfile(root_export, sprintf('%s%s-%02d-e%dm%d-e%dm%d.mat', w, x, y, conf_bb.exp_id, conf_bb.mdl_id, conf_seg.exp_id, conf_seg.mdl_id));
    track.utils.delete(opts_tra)% delete
    results = track.track(opts_tra);
end
