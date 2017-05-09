function data = get_all(opts, data, file_move, file_mitosis, file_enter_exit)

opts_default = struct('max_move',Inf,'move_sampling',1);
opts = bia.utils.updatefields(opts_default, opts);
max_dist      = opts.max_move;
move_sampling = opts.move_sampling;

if opts.use_move
    if exist(file_move, 'file')
        load(file_move, 'mv_edges', 'mv_feats', 'mv_labels', 'mv_errors')
    else
        [mv_edges, mv_labels, mv_feats, mv_errors] = track.edges.move(struct('mode',move_sampling,'max_move',max_dist),data.stats, data.gt);
        save(file_move, 'mv_edges', 'mv_feats', 'mv_labels', 'mv_errors', '-v7.3')
    end
    data = bia.utils.setfields(data, 'mv_edges', mv_edges, 'mv_labels', mv_labels, 'mv_feats', mv_feats, 'mv_errors', mv_errors);
end


if opts.use_mitosis
    if exist(file_mitosis, 'file')
        load(file_mitosis, 'mit_edges', 'mit_labels', 'mit_feats', 'mit_feats_train', 'mit_labels_train', 'mit_errors')
    else
        [mit_edges, mit_labels, mit_errors] = track.edges.mitosis(opts, data.stats, data.gt, data.ims);
        [mit_feats, mit_labels, mit_feats_train, mit_labels_train] = track.edges.feats_mitosis(mit_edges, mit_labels, data.stats, data.gt.sz);
        mit_edges(:,6) = 0;% [id1 dau1 dau2 p]
        save(file_mitosis, 'mit_edges', 'mit_labels', 'mit_feats', 'mit_feats_train', 'mit_labels_train', 'mit_errors', '-v7.3')
    end
    data = bia.utils.setfields(data, 'mit_edges', mit_edges, 'mit_labels', mit_labels, 'mit_feats', mit_feats, ...
        'mit_feats_train', mit_feats_train, 'mit_labels_train', mit_labels_train, 'mit_errors', mit_errors);
end


if opts.use_enter || opts.use_exit
    if exist(file_enter_exit, 'file')
        load(file_enter_exit,'enter_feats','exit_feats','enter_labels','exit_labels')
    else
        gt = data.gt;
        [~, map_id] = bia.convert.id(data.stats);
        feats = bia.ml.stats2mat(data.stats);
        enter_feats = feats;
        enter_labels= zeros(size(enter_feats, 1), 1);
        exit_feats  = feats;
        exit_labels = zeros(size(enter_feats, 1), 1);

        if isfield(gt, 'tra')
            info = gt.tra.info;
            num_tra  = sum(cellfun(@(x) length(x), gt.tra.stats));
        else
            info = [];
            num_tra  = 0;
        end
        T = gt.T;

        [~, ~, id_leave, t_leave, id_enter, t_enter] = bia.track.events([],info);
        for t=1:T
            cents_gt = zeros(num_tra, 2);
            if isfield(gt, 'tra')
                [gt_cc, idx_gt] = bia.convert.centroids(gt.tra.stats{t});
            else
                gt_cc = zeros(0,2);
                idx_gt = [];
            end
            cents_gt(idx_gt,:) = round(gt_cc);

            id_enter_t = id_enter(t_enter == t);
            id_leave_t = id_leave(t_leave == t);

            id_enter_t = intersect(idx_gt, id_enter_t);
            cents_enter = cents_gt(id_enter_t,:);

            id_leave_t = intersect(idx_gt, id_leave_t);
            cents_leave = cents_gt(id_leave_t,:);

            res_rect = bia.convert.bb(data.stats{t},'s2r');
            for j=1:size(res_rect,1)
                id_vec = map_id.stat2mat{t}(j);
                bb = res_rect(j, :);
                in = sum(bb(1) <= gt_cc(:,2) & bb(2) >= gt_cc(:,2) & bb(3) <= gt_cc(:,1) & bb(4) >= gt_cc(:,1));
                in_enter = sum(bb(1) <= cents_enter(:,2) & bb(2) >= cents_enter(:,2) & bb(3) <= cents_enter(:,1) & bb(4) >= cents_enter(:,1));
                in_leave = sum(bb(1) <= cents_leave(:,2) & bb(2) >= cents_leave(:,2) & bb(3) <= cents_leave(:,1) & bb(4) >= cents_leave(:,1));
                if in == 1 && in_enter == 1
                    enter_labels(id_vec) = 1;
                end
                if in == 1 && in_leave == 1
                    exit_labels(id_vec) = 1;
                end
            end
        end
        save(file_enter_exit, 'enter_feats','exit_feats','enter_labels','exit_labels','-v7.3')
    end
    data = bia.utils.setfields(data,'enter_feats',enter_feats,'exit_feats',exit_feats,'enter_labels',enter_labels,'exit_labels',exit_labels);
end

end
