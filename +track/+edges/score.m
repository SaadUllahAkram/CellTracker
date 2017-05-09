function test_data = score(opts, test_data, train_data, s)

opts_move    = opts.opts_move;
opts_mitosis = opts.opts_mitosis;
opts_enter   = opts.opts_enter;
opts_exit    = opts_enter;

if length(s) > 1;   s = 0;  end

file_move = opts.fun.move_model(opts.train_str{2}, s);
file_mitosis = opts.fun.mitosis_model(opts.train_str{2}, s);
file_enter = opts.fun.enter_model(opts.train_str{2}, s);
file_exit = opts.fun.exit_model(opts.train_str{2}, s);

if opts.use_move
    if exist(file_move, 'file')
        load(file_move, 'mdl')
    else
        % to do, gather props close to 'x' dist in next 3 frames and compute feats, save in bb_res -> [t1 t2 id1 id2]
        [train_feats, train_labels] = gather_train_data(train_data, 'mv_feats', 'mv_labels');
        [~, ~, mdl] = bia.ml.train(opts_move, '', '', train_feats, train_labels);
        save(file_move, 'mdl')
    end
    test_feats = test_data.mv_feats;
    test_labels = test_data.mv_labels;
    [~, test_scores] = bia.ml.train(opts_move, test_feats, test_labels, '', '', mdl);
    move_data = [test_data.mv_edges, test_scores(:,2)];
    test_data.edges_move = move_data;
end


if opts.use_mitosis
    if exist(file_mitosis, 'file')
        load(file_mitosis, 'mdl')
    else
        [train_feats, train_labels] = gather_train_data(train_data, 'mit_feats', 'mit_labels');
        [~, ~, mdl] = bia.ml.train(opts_mitosis, '', '', train_feats, train_labels);
        save(file_mitosis, 'mdl')
    end
    [~, mit_scores] = bia.ml.train(opts_mitosis, test_data.mit_feats, test_data.mit_labels, '', '', mdl);
    mitosis_edges = test_data.mit_edges;
    if size(mit_scores,2) == 2;    mitosis_edges(:,5) = mit_scores(:,2);
    else;   mitosis_edges(:,5) = 0;
    end
    test_data.edges_mitosis = mitosis_edges(:,1:5);% [id1 dau1 dau2 p]
else
    test_data.edges_mitosis = zeros(0,5);%[t_parent parent_id t_dau1 daughter1 t_dau2 daughter2 p]
end

cents = [];
for t=1:length(test_data.stats)
   cents =  [cents; bia.convert.centroids(test_data.stats{t})];
end
N = size(cents,1);

d_thresh = 2*opts.max_move;
d_from_border = min(cents, [], 2);
% d_thresh = 2*opts.max_move + train_data{1}.gt.foi_border;
prob = 0.01*(1 - d_from_border/d_thresh);
prob( prob <=0 ) = 10^-5;

if opts.use_enter
    if opts.out_type == 1% learn a classifier
        if exist(file_enter, 'file')
            load(file_enter, 'mdl')
        else
            [train_feats, train_labels] = gather_train_data(train_data, 'enter_feats', 'enter_labels');
            [~, ~, mdl] = bia.ml.train(opts_enter, '', '', train_feats, train_labels);
            save(file_enter, 'mdl')
        end
        [~, scores_enter] = bia.ml.train(opts_enter, test_data.enter_feats, test_data.enter_labels, '', '', mdl);
    elseif opts.out_type == 2% has fixed value
        if exist(file_enter, 'file')
            load(file_enter, 'mdl')
            prob_enter = mdl;
        else
            prob_enter = gather_train_data(train_data, 'p_enter', 'p_enter');
            mdl = prob_enter;
            save(file_enter, 'mdl')
        end
        prob_enter = mean(prob_enter);
        scores_enter = prob_enter*ones(N, 1);
        
    elseif opts.out_type == 3% based on dist from border
        scores_enter = prob;
    end
else
    M = sum(arrayfun(@(x) length(x{1}), test_data.stats));
    scores_enter = ones(M, 1);
end
N = length(scores_enter);
test_data.edges_enter = [zeros(N,1), [1:N]', scores_enter];


if opts.use_exit
    if opts.out_type == 1
        if exist(file_exit, 'file')
            load(file_exit, 'mdl')
        else
            [train_feats, train_labels] = gather_train_data(train_data, 'exit_feats', 'exit_labels');
            [~, ~, mdl] = bia.ml.train(opts_exit, '', '', train_feats, train_labels);
            save(file_exit, 'mdl')
        end
        [~, scores_exit] = bia.ml.train(opts_exit, test_data.exit_feats, test_data.exit_labels, '', '', mdl);
    elseif opts.out_type == 2% has fixed value
        if exist(file_exit, 'file')
            load(file_exit, 'mdl')
            prob_exit = mdl;
        else
            prob_exit = gather_train_data(train_data, 'p_exit', 'p_exit');
            mdl = prob_exit;
            save(file_exit, 'mdl')
        end
        prob_exit = mean(prob_exit);
        scores_exit = prob_exit*ones(N, 1);
    elseif opts.out_type == 3% based on dist from border
        scores_exit = prob;
    end
else
    M = sum(arrayfun(@(x) length(x{1}), test_data.stats));
    scores_exit = ones(M, 1);
end
N = length(scores_exit);
test_data.edges_exit = [[1:N]', zeros(N,1), scores_exit];

end


function [train_feats, train_labels] = gather_train_data(train_data, field_feats, field_labels)
train_feats = [];
train_labels = [];
n_train = length(train_data);
for i=1:n_train
    train_feats = [train_feats; train_data{i}.(field_feats)];
    train_labels = [train_labels; train_data{i}.(field_labels)];
end

if sum(train_labels == -1)
    idx_rm = train_labels == -1;
    train_feats(idx_rm, :) = [];
    train_labels(idx_rm) = [];
end
end
