function [counts, errors] = eval_graph(gt, stats, graph, verbose)
if nargin < 4;  verbose = 0;    end
[~,~,~,err_mo] = bia.metrics.ap_edges(struct('move',1), gt, stats, graph.edges_move);
[~,~,~,err_mit] = bia.metrics.ap_edges(struct('mitosis',1), gt, stats, [graph.edges_mitosis(:,1:3);graph.edges_mitosis(:,4:6)]);
[fn, fn_ns] = eval_fn(stats, gt, 1);

gt_stats = bia.datasets.stats(struct('verbose',0),rmfield(gt,'seg'));

% fn1_props: outside all props
counts = struct('fn1_props', size(fn,1), 'fn2_props', size(fn_ns,1),...
    'fn_move', size(err_mo.fn,1), 'fn_mitosis', size(err_mit.fn,1),...
    'gt_markers',gt_stats.n_markers, 'gt_mitosis_edges', gt_stats.n_mitosis_edges,...
    'gt_move_edges', gt_stats.n_move_edges);

errors = struct('fn1_props', fn, 'fn2_props', fn_ns,...
    'fn_move', err_mo.fn,'fn_mitosis', err_mit.fn);

if verbose
    fprintf('Proposal Graph: FNs:: Mitosis:%d, Move:%d, Proposals:%d+%d\n', counts.fn_mitosis, counts.fn_move, counts.fn1_props, counts.fn2_props);
end
end


function [fn, fn_ns] = eval_fn(stats, gt, type)
% fn: gt cells outside all props
% type : 1
    % fn_ns: gt cell that only occur inside a proposal with another gt cell (under segmented)
% type : 1
    % fn_ns: gt cell that 1) occur inside a proposal with another gt cell (under segmented) 2) are outside all props
eval_type = 1;%1(CTC-TRA criteria), 2(markers)
fn = [];
fn_ns = [];
for t=1:gt.T
    stats_loc = stats{t};
    if eval_type == 1
        gt_active = find([gt.tra.stats{t}.Area]);
        iou_ctc = bia.utils.overlap_pixels(gt.tra.stats{t}, stats_loc, 0.5);
        n = length(gt.tra.stats{t});
        m = length(stats_loc);
        for i=gt_active
            if sum(iou_ctc(i,:)) == 0
                fn = [fn; t i];
            end
        end
        % get rid of ns props
        for i=1:m
            if sum(iou_ctc(:,i)>0) > 1
                iou_ctc(:,i) = 0;
            end
        end
        % find strict fn: all GT which do not have a good (only 1 marker inside) match
        for i=gt_active
            if sum(iou_ctc(i,:)) == 0
                fn_ns = [fn_ns; t i];
            end
        end
    end
end
% get rid of fn from fn_ns
if type == 2
    for i=1:size(fn)
       fn_ns(fn_ns(:,1) == fn(i,1) & fn_ns(:,2) == fn(i,2),:) = [];
    end
end
    
% if eval_type == 2
%     [~,~,~,~,e] = bia.metrics.ap_markers(1, stats_loc, gt, 0);
%     fns(1,l+1) = size(e.fn,1);
% end
% fn = sum(fns);
end