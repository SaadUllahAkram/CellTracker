function info = tracks_info(stats, info, idx)
% idx: tracks which were deleted
T = length(stats);
K = length(stats{1});

% update old info:
if nargin > 1
    M = max(info(:,1));
    del = setdiff(1:M, idx);

    for i=1:length(del)
        info(info(:,1)==del(i), :) = [];
        info(info(:,4)==del(i), 4) = 0;
    end

    % map old ids to new ids: as some tracks were deleted previously
    map = zeros(1,M);
    for i=1:M
        map(i) = i-sum(del<i);
    end
    for i=1:size(info,1)
        if info(i,1) ~= 0
            info(i,1) = map(info(i,1));
        end
        if info(i,4) ~= 0
            info(i,4) = map(info(i,4));
        end
    end
else
    info = zeros(K,4);
end
% create info
del_k   = [];
for k=1:K
    %tl          = arrayfun(@(x,y) stats{x}(y).Area, 1:T, repmat(k,1,T));
    tl          = arrayfun(@(x) stats{x}(k).Area, 1:T);
    t_start     = find(tl,1,'first');
    t_end       = find(tl,1,'last');
    if isempty(t_start)
        % assert(isempty(t_end))
        del_k = [del_k, k];
    else
%         info_3(k,:) = [k, t_start, t_end];
        info(k, :)  = [k, t_start, t_end, info(k,4)];% [track_d, track_start, track_end, parent_id]
    end
end
info(del_k,:) = [];
end