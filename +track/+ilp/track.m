function [stats_tra, info, score, p_score] = track(opts, opts_tra, data, graph)

sz = data.gt.sz;

[stats_tra, info, score, p_score] = track.ilp.solve(opts_tra, data.stats, graph);

stats_tra = bia.seg.rm_duplicate_pixels(stats_tra, sz);
stats_tra = bia.struct.fill(stats_tra);

% remove regions samller than a given size
for t=1:length(stats_tra)
    areas = [stats_tra{t}(:).Area];
    idx_rm = find(areas < opts.min_size & areas > 0);
    for k = idx_rm
        stats_tra{t}(k) = bia.utils.setfields(stats_tra{t}(k), 'Area',0,'PixelIdxList',[],'Centroid',[NaN NaN],'BoundingBox',[.5 .5 0 0]);
    end
end
[stats_tra, idx] = bia.struct.standardize(stats_tra);
info = track.utils.tracks_info(stats_tra, info, idx);
end