function tracks = eval(opts, stats_tra, info_tra, gt, stats_props, stats_seg)
opts_default = struct('proposal','','post_dilate',[]);
opts = bia.utils.updatefields(opts_default, opts);
method = opts.proposal;

[tra, counts, errors] = bia.metrics.tra(stats_tra, info_tra, gt);
[seg_tra, segf_tra] = bia.metrics.seg([], stats_tra, gt);
[seg, segf] = bia.metrics.seg([], stats_seg, gt);
if ~isempty(stats_props)
    [segp, segpf] = bia.metrics.seg(struct('proposals',1), stats_props, gt);
else
    segp = 0;    segpf = 0;
end

[stats_tra_red, idx_tra_red] = bia.struct.reduce_memory(1, stats_tra);
tracks = struct('tracks',struct('stats_tra_red',{stats_tra_red},'idx_tra_red',{idx_tra_red},'info',info_tra),'seg',[seg segf segp segpf],'tra',tra,'counts',counts,'errors',errors,'seg_tra',[seg_tra,segf_tra]);
if numel(opts.post_dilate) > 1
    [stats_seg_red, idx_seg_red] = bia.struct.reduce_memory(1, stats_seg);
    tracks.stats_seg_red = stats_seg_red;
    tracks.idx_seg_red = idx_seg_red;
end

tracks.res_str = sprintf('TRA:%1.4f, SEG:[%1.4f->%1.4f, D:%1.4f->%1.4f], SEGP:[%1.4f->%1.4f], FN:%d, FP:%d, NS:%d, EA:%d, EC:%d, ED2:%d, ED1(0):%d, TP:%d, MIT:(F1:%1.3f,R:%1.3f,P:%1.3f),(TP:%d, FN:%d, FP:%d)\n',....
    tra, seg, segf, seg_tra, segf_tra, segp, segpf, counts.fn, counts.fp, counts.ns, counts.ea, counts.ec, counts.ed2, counts.ed1, counts.tp, counts.mitosis_f1, counts.mitosis_recall, counts.mitosis_precision, counts.mitosis_tp, counts.mitosis_fn, counts.mitosis_fp);
tracks.latex = sprintf('%8s & %8s & %1.3f & %1.3f & %5d & %5d & %5d & %5d & %5d & %5d\\\\', '', method, tra, seg, counts.fn, counts.fp, counts.ns, counts.ea, counts.ec, counts.ed2);
end