function [data, tracks] = solve(opts, opts_tra, s, data, graph, solver)

do_dilate = numel(opts.post_dilate) > 1;
foi_border = data.gt.foi_border;

opts.seq = sprintf('%s-%02d', opts.dataset, s);
opts_props = opts.opts_props;
opts_video = opts.opts_video;
opts_props.save_path = opts_props.save_path_fun(s);
opts_video.save_path = opts_video.save_path_fun(s);

sz = data.gt.sz;
T  = data.gt.T;
t_start = tic;

[~,map] = bia.convert.id(data.stats);
data.mat2stat = map.mat2stat;
if strcmp(solver, 'sp')% shortest path
    [stats_tra, info, score, p_score] = track.sp.track(opts, opts_tra, data, graph.graph_sp, map);
elseif strcmp(solver, 'ilp')% ILP
    [stats_tra, info, score, p_score] = track.ilp.track(opts, opts_tra, data, graph.graph_ilp);
end

if do_dilate% 'PhC-C2DL-PSC' & 'PhC-C2DH-U373'
    % fprintf('Post-processing: Dilating Cell Masks\n')
    stats_seg = stats_tra;
    stats_tra = dilate(stats_tra, sz, opts.post_dilate);
    stats_tra = bia.seg.rm_duplicate_pixels(stats_tra, sz);
end

if opts.post_rm_border
    for t=1:T
        stats_tra{t} = bia.utils.rm_border_regions(stats_tra{t}, sz(t,:), foi_border);
    end
    stats_tra = bia.struct.fill(stats_tra);
    
    if do_dilate
        for t=1:T
            stats_seg{t} = bia.utils.rm_border_regions(stats_seg{t}, sz(t,:), foi_border);
        end
        stats_seg = bia.struct.fill(stats_seg);
    end
end

% fprintf('Tracking post-processing took: %1.1f sec\n', toc(t_start))

stats_tra = fill_gap(stats_tra, info);
stats_tra = bia.seg.rm_duplicate_pixels(stats_tra, sz);

[stats_tra, idx] = bia.struct.standardize(stats_tra);
info = track.utils.tracks_info(stats_tra, info, idx);

% bia.metrics.ctc_official(data.gt, stats_tra, info);
if do_dilate
    tracks = track.eval(opts, stats_tra, info, data.gt, data.stats, stats_seg);
else
    tracks = track.eval(opts, stats_tra, info, data.gt, data.stats, stats_tra);
end

data.stats_tra = stats_tra;
data.info      = info;

% fprintf('%s', tracks.res_str)
% fprintf('%s:: #Tracks:%d->%d, Score: %10.1f, P-score:%10.1f:: %s', solver, K, length(stats_tra{end}), score, p_score, tracks.res_str)
% fprintf('%s:%s:%3.0fs:: Score: %10.1f, Score(props):%10.1f:: %s', sprintf('%3d', opts.exp_id), solver, toc(t_start), score, p_score, tracks.res_str)
fprintf('%s:%s:%3.0fs:: %s', sprintf('%3d', opts.exp_id), solver, toc(t_start), tracks.res_str)

if do_dilate
    if opts.video_view;    save_vid(opts, data.ims, stats_seg, foi_border);   end
else
    if opts.video_view;    save_vid(opts, data.ims, data.stats_tra, foi_border);   end
end
if opts.video_props;    bia.plot.proposals(opts_props,data.stats, data.ims); end
if opts.video_tracks;   bia.plot.tracks(opts_video, data.ims, data.stats_tra, data.info, data.gt); end
if opts.video_errors;   track.errors_video(opts_video, data.ims, data.stats_tra, data.info, data.gt, tracks.errors); end
end



function save_vid(opts, ims, stats, foi)
% sqrt : hela, gowt1
if strcmp(opts.dataset, 'Fluo-N2DL-HeLa') || strcmp(opts.dataset, 'Fluo-N2DH-GOWT1')
    fun = @(x) bia.prep.norm(x,'sqrt');
else
    fun = @(x) (x);
end
% ims = ims(opts.vid.tl,1);
% stats = stats(opts.vid.tl,1);
T = length(ims);
cap = cell(T,1);
for t=1:T
    im = bia.draw.roi(struct('out',[0 0 0],'in',[255 0 0]), fun(ims{t}), foi);
    %     imshow(im)
    mask = bia.convert.stat2im(stats{t}, [size(im,1), size(im,2)]);
    cap{t} = bia.draw.boundary(struct('alpha',0.9,'fun_boundary',@boundarymask), im, mask);
    %     imshow(cap{t})
end
bia.save.video(cap, fullfile(opts.root_data, sprintf('tracks-%s.avi', opts.seq)),2)
save(fullfile(opts.root_data, sprintf('tracks-%s.mat', opts.seq)), 'cap')
end


function stats = dilate(stats, sz, se)
for t=1:length(stats)
    idx = find([stats{t}(:).Area] > 0);
    if size(idx,1) > 1; idx = idx';end
    for i=idx
        % todo: use tight+border_thickness rect for creating individual boundaries for speed up
        mask = bia.convert.stat2im(stats{t}(i), sz(t,:));
        mask = imdilate(mask, se);
        tmp = regionprops(mask, 'Area', 'BoundingBox', 'Centroid', 'PixelIdxList');
        if ~isempty(tmp)
            stats{t}(i) = bia.utils.setfields(stats{t}(i),'Area',tmp.Area,'BoundingBox',tmp.BoundingBox,'Centroid',tmp.Centroid,'PixelIdxList',tmp.PixelIdxList);
        end
    end
end

end


function stats = fill_gap(stats, info)
% add the last detected object in frames in which a track has no detection
for k=info(:,1)'
    tl = arrayfun(@(x) x{1}(k).Area, stats);
    ts = find(tl,1,'first');
    te = find(tl,1,'last');
    for t=ts:te
        if stats{t}(k).Area == 0
            % fprintf('%d:%d\n', k, t)
            stats{t}(k) = stats{t-1}(k);
        end
    end
end

end


function abc()

xp = zeros(graph.graph_ilp.N, 1);
pa = [];
for i=1:length(paths)
    pa=[pa;paths{i}];
end
pa = cellfun(@(x) str2double(x), pa);
for i=1:length(pa)
    xp(pa(i))=1;
end
b = graph.graph_ilp.A(:,1:graph.graph_ilp.N)*xp;

if (bia.utils.ssum(xp) ~= length(pa)); warning('Some prop is in multiple paths'); end
if (max(b) ~= 1); warning('%d', max(b)); end

end