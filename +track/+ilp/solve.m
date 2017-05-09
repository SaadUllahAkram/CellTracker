function [stats, info, ilp_score, p_score] = solve(opts, props, graph)
% ILP tracker
%
% Inputs:
%     opts: options
%     props: proposal stats
%     graph: ILP graph
% Outputs:
%     stats: track stats
%     info: track events: [id t_start t_end parent_id]
%     ilp_score: solution score
% 

opts_default = struct('ilp_solver','gurobi','verbose',0,'debug',0);
opts = bia.utils.updatefields(opts_default, opts);

solver = opts.ilp_solver;
debug  = opts.debug;
verbose= opts.verbose;

N = graph.N;
E = graph.E;
edges = graph.edges;
cost_props = graph.f(1:N);

if strcmp(solver, 'matlab')
    warning('code has changed: need updating')
    intcon = 1:(N+E);% all edge & prop selection variables are int
    A = [graph.A;
        [-speye(N, N), sparse(N, E)];...% add binary constraints (proposals): x >= 0
        [sparse(E, N), -speye(E,E)]];% add binary constraints (edges): x >= 0
    b = [graph.b; zeros(N,1); zeros(E,1)];
    options = optimoptions(@intlinprog,'display','off');
    root = pwd;
    % cd('path2matlab/matlab-r2017a/toolbox/optim/optim/')% to prevent conflict with another "intlinprog"
    [x, ilp_score] = intlinprog(graph.f, intcon, A, b, graph.Aeq, graph.beq, [],[], options);
    cd(root)
    x = logical(x);
elseif strcmp(solver, 'gurobi')
    model = struct('obj', graph.f, 'vtype', 'B', 'modelsense', 'min');
    model.A     = [graph.A; graph.Aeq];
    model.rhs   = [graph.b+0.0001; graph.beq];
    model.sense = [repmat('<', size(graph.b)); repmat('=', size(graph.beq))];
    
    result = gurobi(model, struct('outputflag', 0));
    ilp_score = result.objval;
    x = result.x;
    assert(sum(abs(x-1) < 10^-4 | abs(x) < 10^-4) == length(x), 'Some variables might not be binary')
    x = logical(round(x));
    if ~strcmp(result.status, 'OPTIMAL');        fprintf('STATUS: %s, Time: %1.2f\n', result.status, result.runtime);    end
end
x_props = x(1:N);
x_edges = x(N+1:N+E);
s_edges = edges(x_edges, :);% selected edges
if verbose
    fprintf('Detected Mitosis Counts: %d\n', sum(s_edges(:,4)==4));
end

birth_edges = find(s_edges(:,1) == 0);
death_edges = find(s_edges(:,2) == 0);

map = cell2mat(arrayfun(@(x,y) [x*ones(length(y{1}),1), [1:length(y{1})]'], [1:length(props)]', props, 'UniformOutput',false));

K = length(birth_edges) + 2*(length(death_edges) - length(birth_edges));
tracks = cell(K, 1);
info   = zeros(K, 4);

birth_info = [s_edges(birth_edges, 2), zeros(length(birth_edges),1)];% [1st prop_id (node with in-edge), parent_id]
k = 0;
% create track paths from selected edges
while ~isempty(birth_info)
    k = k+1;
    tracks{k} = [];
    id   = birth_info(end,1);
    b_id = id;
    while(id ~= 0)
        tracks{k} = [tracks{k}, id];
        id_prev = id;
        id = find_child(s_edges, id);
        if length(id) > 1
            %birth_new = add_mit(s_edges, [id, [id_prev;id_prev]]);
            birth_new  = [id, [id_prev;id_prev]];
            birth_info = [birth_new; birth_info];
            break
        end
    end
    info(k, :)  = [k, map(b_id,1), map(id_prev,1), birth_info(end,2)];
    birth_info(end,:) = [];
end

if debug
    assert(K == length(tracks), 'Number of tracks is unexpected')
    assert(length(birth_edges) <= length(death_edges), 'Birth edges can not be more than death edges')
    assert(bia.utils.ssum(in) == bia.utils.ssum(both == -1))
    assert(bia.utils.ssum(out) == bia.utils.ssum(both == 1))
    assert(sum(s_edges(:,4)==4) == sum(s_edges(:,4)==5), 'Miss-match in daughter 1 and daughter 2 edges')
    % check that results are consistent
    found = find(x_props);
    for k=1:K;  assert(sum(ismember(tracks{k}, found)) ~= length(tracks{k}), 'Something is wrong with paths');  end

    counts1 = sum(cellfun(@(x) length(x), tracks));
    assert(counts1 == sum(x_props))

    idx = [s_edges(:,1);s_edges(:,2)];
    idx(idx==0) = [];
    for k=1:max(idx);   ss(k)=sum(idx==k);    end
    assert(max(ss) <= 3, 'Number of edges that a node is involved in is unexpected')

    e_move  = edges(edges(:,4) == 1, :);
    e_enter = edges(edges(:,4) == 2, :);
    e_exit  = edges(edges(:,4) == 3, :);

    p_scores = zeros(1,K);
    p_move   = zeros(1,K);
    for k=1:K
        enter(k) = e_enter(e_enter(:,2)==tracks{k}(1),3);
        exit(k)  = e_exit(e_exit(:,1)==tracks{k}(end),3);

        for i=1:length(tracks{k})
            r = tracks{k}(i);
            t = map(r, 1);
            id= map(r, 2);
            stats{t,1}(k,1) = props{t}(id);
            p_scores(k) = p_scores(k) + cost_props(r);
            if i < length(tracks{k})
                p_move(k) = p_move(k) + e_move(e_move(:,1)==r & e_move(:,2)==tracks{k}(i+1),3);
            end
        end
    end
    p_score = sum(p_scores);
    score = p_score + sum(enter) + sum(exit) + sum(p_move);    
end

% map parent id (unique prop id) to parent track id
for k=1:K
    id = info(k, 4);
    found = 0;
    if id ~= 0
        for i=1:K
            if ismember(id, tracks{i})
                found = i;
                break
            end
        end
    end
    info(k, 4) = found;
end

% create tracks stats
for k=1:K
    for i=1:length(tracks{k})
        r = tracks{k}(i);
        t = map(r, 1);
        stats{t,1}(k,1) = props{t}(map(r, 2));
    end
end
stats = bia.struct.fill(stats, K);

p_score = sum(graph.f(1:N).*x_props);
end


function out = find_child(edges, id)
out = edges(edges(:,1)==id, 2);
end


function bx = add_mit(edges, id)
x1 = find_child(edges, id(1,1));
if length(x1) == 1
    x1 = [x1, id(1,1)];
else
    x1 = [x1, [id(1,1); id(1,1)]];
end

if size(x1,1) == 2
    x11 = add_mit(edges, x1);
    x1 = [x1; x11];
end
x2 = find_child(edges, id(2,1));
if length(x2) == 1
    x2 = [x2, id(2,1)];
else
    x2 = [x2, [id(2,1); id(2,1)]];
end

if size(x2,1) == 2
    x21 = add_mit(s_edges, x2);
    x2 = [x2; x21];
end
bx = [x1;x2];
end