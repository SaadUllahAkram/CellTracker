function errors_video(opts, ims, stats_tra, info_tra, gt, errors)
% modes:
% 1-> plot3 -> x,y,t
% 2-> [im+traj]
% 3-> [cell borders+traj]
% 4-> [bia.convert.l2rgb+traj]
% 
% Inputs:
%     opts :
%     ims : a cell array of images
%     stats_tra {Area, Centroid, PixelIdxList, BoundingBox}: a cell array of structs, each cell has a unique id (idx in struct)
%     gt : use GT to highlight errors : Segmentation [FP/FN/UnderSeg]/ Tracking [Wrong association/Missed events(Enter/Leave/Mitosis/Apoptosis)]
%
% ToDo:: highlight errors/events -> mitosis/apoptosis/enter/leave
%

opts_default = struct('mode',0,'show_im',0,'save_path','','rect',[],'use_sqrt',0,'verbose',1,'frame_rate',2,...
    'opts_traj', struct('traj_len', [15 0],'line_width',1,'alpha',.5), ...
    'opts_boundary', struct('cmap','prism','border_thickness',1,'alpha',0.5,'fun_boundary',@boundarymask));
opts                = bia.utils.updatefields(opts_default, opts);

frame_rate          = opts.frame_rate;
opts_traj           = opts.opts_traj;
opts_boundary       = opts.opts_boundary;
save_path           = opts.save_path;
save_video          = ~isempty(save_path);
mode                = opts.mode;
show_im             = opts.show_im;
rect                = opts.rect;
use_sqrt            = opts.use_sqrt;
verbose             = opts.verbose;

colors = struct('fn','r','fp','y','ns','g',...
    'ec','g','ea','r','ed2','y');

fn = errors.fn;% [t id]
fp = errors.fp;% [t id]
ns = errors.ns;% [t id]
ec = errors.ec;% []
ea = errors.ea;% []
ed2= errors.ed2;% 

T                   = length(ims);
trajs               = bia.track.tracks_pos(stats_tra);

if ~isempty(rect)
    assert(sum(rect([1 3]) >= [1 1]) == 2)
    assert(sum(rect([2 4]) <= [size(ims{1},1) size(ims{1},2)]) == 2)
end

if save_video
    caps = cell(T,1);
end

if mode == 1
    [fig_h_1,ax_h_1] = bia.plot.fig('Tracking Results: Full Trajectories');
    hold on
    for i=1:length(trajs)
        plot3(ax_h_1, trajs{i}(:,1), trajs{i}(:,2), trajs{i}(:,3))
    end
    xlabel('X')
    ylabel('Y')
    zlabel('Time')
    drawnow
    saveas(fig_h_1, [save_path, '_plot3.fig'])
elseif ismember(mode, [2 3 4])
    if isempty(rect)
        [fig_h, ax_h] = bia.plot.fig('Tracking Results: 2D',[1, 1+show_im]);
    else
        fig_h = figure(1);fullscreen
        ax_h(1) = subplot(1,2,1);hold on
        ax_h(2) = subplot(1,2,2);hold on
    end
    for t=1:T
        if verbose
            fprintf('%d ',t)
        end
        for k=1:length(ax_h)
            cla(ax_h(k), 'reset')
            cla(ax_h(k))
        end
        if use_sqrt
            im      = uint8(255*bia.prep.norm(sqrt(single(ims{t}))));
        else
            im      = bia.prep.norm(ims{t});
        end
        sz      = [size(im, 1), size(im, 2)];
        if show_im
            imshow(im, [], 'parent', ax_h(1))
            if ~isempty(rect)
                axis(ax_h(1), rect([3:4, 1:2]))
            end
        end
        if mode == 2
            im2 = im;
        elseif mode == 3
            im2 = bia.draw.boundary(opts_boundary, im, bia.convert.stat2im(stats_tra{t}, sz));
        elseif mode == 4
            im2 = bia.convert.l2rgb(bia.convert.stat2im(stats_tra{t}, sz));
        end
        
        imshow(im2, 'parent', ax_h(end))
        hold(ax_h(end), 'on')
        axis(ax_h(end), [1 sz(2) 1 sz(1)])
        % bia.plot.tracks_traj(opts_traj, ax_h(end), stats_tra, trajs, t);
        if ~isempty(rect)
            axis(ax_h(end), rect([3:4, 1:2]))
        end
        
        %% plot errors
        % FN
        if ~isempty(fn)
            idx = fn(fn(:,1)==t,2);
            bia.plot.centroids(ax_h(end), gt.tra.stats{t}(idx), colors.fn, 40)
        end
        % FP
        if ~isempty(fp)
            idx = fp(fp(:,1)==t,2);
            bia.plot.centroids(ax_h(end), stats_tra{t}(idx), colors.fp, 40)
        end
        % NS
        if ~isempty(ns)
            idx = ns(ns(:,1)==t,2);
            bia.plot.centroids(ax_h(end), stats_tra{t}(idx), colors.ns, 40)
        end
        % MIT::
%         idx = errors.MIT(errors.MIT(:,1)==t,2);
%         bia.plot.centroids(ax_h(end), stats_tra{t}(idx), 'b', 50)
        % EC
        idx = ec(ec(:,1)==t,3);
        plot_b(ax_h(end), stats_tra{t}(idx), colors.ec)
        % EA
        idx = ea(ea(:,1)==t,3);
        plot_b(ax_h(end), gt.tra.stats{t}(idx), colors.ea)
        % ED
        idx = ed2(ed2(:,1)==t,3);
        plot_b(ax_h(end), stats_tra{t}(idx), colors.ed2)
        %%
        drawnow
        if save_video
            caps{t} = bia.save.getframe(fig_h);
        end
    end
    if verbose
        fprintf('\n')
    end
    if save_video
        bia.save.video(caps, sprintf('%s_2d_mode%d_errors.avi', save_path, mode),frame_rate)
    end
end
end

function plot_b(ax, b, c, style)
% '-'
% '--'
% ':'
% '-.'
if nargin == 3
    style = '-';
end
w = 15;
for i=1:length(b)
    if isnan(b(i).Centroid(1))
        continue
    end
    x = b(i).Centroid - w;
    x = [x, 2*w, 2*w];
    rectangle('Parent', ax, 'Position', x, 'EdgeColor', c, 'LineWidth', 1, 'LineStyle', style);
end
end