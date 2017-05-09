function show_errors(opts, ims, gt, stats, errors)
% mitosis: FNs(parent, daughter), FNs(due to crowd or distance)
% move: FNs(match or distance)

opts_default = struct('root','','dataset','','type','');
opts = bia.utils.updatefields(opts_default, opts);

[hfig,hax] = bia.plot.fig(sprintf('%s: %s errors', opts.dataset, opts.type), [1 2], 0, 1);

if strcmp(opts.type, 'move')
    edges = errors.fn;
    edges = edges(:,[1 2 1 3]);
    edges(:,3) = edges(:,3)+1;
elseif strcmp(opts.type, 'mitosis')
    edges = errors.fn;
elseif strcmp(opts.type, 'props')

end
plot_error(opts, hfig, hax, edges, stats, ims, gt.tra.stats);

end


function plot_error(opts, hfig, hax, edges, stats, ims, gt_stats)
dataset = opts.dataset;
root = opts.root;
type = opts.type;
t_list = unique([edges(:,1); edges(:,3)]');
parfor t=1:length(ims)
   ims{t} = bia.prep.norm(ims{t},'sqrt');
   ims{t} = bia.draw.boundary([],ims{t},stats{t});
   olap{t} = bia.utils.overlap_pixels(gt_stats{t}, stats{t});
end
for i=1:size(edges,1)
    cla(hax(1))
    cla(hax(2))
    if rem(i,50) == 0
        fprintf('%d ',i)
    end
    t = edges(i,1);
    tn= edges(i,3);
    p_id = edges(i,2);
    d_id = edges(i,4);
    ot = olap{t};
    otn= olap{tn};
    idxt = ot(p_id,:)'>0;
    idxtn= otn(d_id,:)'>0;
    r1 = bia.convert.rect(struct('pad',0), [gt_stats{t}(p_id); gt_stats{tn}(d_id)]);
    r2 = bia.convert.rect(struct('pad',0), [stats{t}(idxt); stats{tn}(idxtn)]);
    r = bia.convert.rect(struct('pad',25), [r1;r2]);

    imshow(ims{t},'parent',hax(1));
    bia.plot.centroids(hax(1),gt_stats{t},'g')
    bia.plot.centroids(hax(1),gt_stats{t}(p_id))
    axis(hax(1), r([3 4 1 2]))
    
    imshow(ims{tn},'parent',hax(2));
    bia.plot.centroids(hax(2),gt_stats{tn},'g')
    bia.plot.centroids(hax(2),gt_stats{tn}(d_id))
    axis(hax(2), r([3 4 1 2]))
    im_cap = bia.save.getframe(hfig);
    if ~isempty(root)
        imwrite(im_cap, fullfile(root, sprintf('%s-%s-t%02d_i%04d_j%04d.png', dataset, type, t, p_id, d_id)))
    end
end
fprintf('\n')
end
