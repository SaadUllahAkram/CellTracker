function [tracks, data_test] = track(opts)

diary(opts.file.diary)
t_start = tic;

type_id = opts.train_str;% string identifier distinguishing test/train data
test_seq = opts.test_seq;
train_seq = opts.train_seq;
n_train = length(train_seq);


track.utils.pack(2, opts, train_seq);
% prepare data for training
data_train = cell(n_train, 1);
for s=1:n_train
    data_train{s} = track.utils.load(opts, train_seq(s), 1);
end
data_test = track.utils.load(opts, test_seq, 0);


if strcmp(opts.proposal, 'blob')
    data_test = proposal.score(opts, data_test, data_train, opts.fun.cell_model(type_id{1},test_seq));
    for s=1:n_train
        data_train{s} = proposal.score(opts, data_train{s}, data_train, opts.fun.cell_model(type_id{1},test_seq));
    end
end
if opts.verbose; fprintf('### Loaded Proposals: %1.1f sec\n', toc(t_start)); end


for s=1:n_train
    data_train{s} = track.edges.get_all(opts, data_train{s}, opts.fun.move_feats(type_id{2},train_seq(s)), opts.fun.mitosis_feats(type_id{2},train_seq(s)), opts.fun.enter_exit_feats(type_id{2},train_seq(s)));
end
data_test = track.edges.get_all(opts, data_test, opts.fun.move_feats(type_id{1},test_seq), opts.fun.mitosis_feats(type_id{1},test_seq), opts.fun.enter_exit_feats(type_id{1},test_seq));
data_test = track.edges.score(opts, data_test, data_train, train_seq);
if opts.verbose; fprintf('### Loaded Edges : %1.1f\n', toc(t_start)); end


graphs = track.graph(opts, data_test);
[data_test, tracks] = track.solve(opts, opts, test_seq, data_test, graphs, opts.solver);


track.utils.pack(1, opts, train_seq);

if opts.save_res
    save(opts.fun.graph(type_id{1}, test_seq), 'graphs')
    save(opts.fun.tracks(type_id{1}, test_seq), 'tracks')
end

if opts.verbose;    fprintf('Total Time:%1.1fmin\n', toc(t_start)/60);  end
diary off

end