function graph_ilp = graph(graph)
conflicts = prop_conflicts(graph.constraints);

cost_props = graph.prop_nodes;%[p]
e_enter = graph.edges_enter(:,1:3);%[0 id p]
e_exit  = graph.edges_exit(:,1:3);%[id 0 p]
e_move  = graph.edges_move(:,1:3);%[id1 id2 p]
e_mit1  = graph.edges_mitosis(:,1:3);%[parent daughter1 p]
e_mit2  = graph.edges_mitosis(:,4:6);%[parent daughter2 p]

e_move(:,4) = 1;
e_enter(:,4)= 2;
e_exit(:,4) = 3;
e_mit1(:,4) = 4;
e_mit2(:,4) = 5;
mit_pad = zeros(size(e_mit2));

edges1  = [e_move; e_enter; e_exit];
edges2  = [e_mit1; e_mit2];
edges3  = [e_mit1; mit_pad];
edges   = [edges1; edges2];
edgesx  = [edges1; edges3];
e1      = size(edges1, 1);
me      = 0.5*size(edges2, 1);% num of mitosis edge pairs
E       = size(edges, 1);
N       = size(cost_props, 1);

prop_offsets = arrayfun(@(x) size(x{1},1), graph.conflicts);

out     = in_out2(edgesx, 1, prop_offsets);% out
in      = in_out2(edges, 2, prop_offsets);% in

% out2     = in_out(edgesx, 1);% out
% in2      = in_out(edges, 2);% in
% assert(isequal(in2, in))
% assert(isequal(out2, out))

both    = out - in;
f = [cost_props; edges(:,3)];

% add overlap constraints
C = size(conflicts, 1);
A = [double(conflicts>0), sparse(C, E)];% prop conflicts
b = ones(C, 1);
% edges_in - edges_out = 0;
Aeq = [sparse(N, N) both;...% #in edges == #out edges
    [speye(N, N), -in];...% if a prop is active then '1' in edge must be active as well
    [sparse(me, N+e1), speye(me), -speye(me)];...% if 1 mitosis edge is active then both edges have to be active
    ];
beq = [zeros(N, 1);...
    zeros(N, 1);
    zeros(me, 1);];
graph_ilp = struct('f',f,'N',N,'E',E,'A',A,'b',b,'Aeq',Aeq,'beq',beq,...
    'edges',edges);
end


function m = in_out2(edges, in_out, prop_offsets)
% in_out: 1->out edge, 2-> in edge
N = max(max(edges(:,1:2)));
E = size(edges, 1);
m = sparse(N, E);

rv = [];
cv = [];
c = cell(N,1);
tlist = [];
T = length(prop_offsets);
eds_idx = cell(T,1);
eds = cell(T,1);
prop_offsetsssss = cumsum([0; prop_offsets])';
for t = 1:T
    tlist = [tlist, t*ones(1, prop_offsets(t))];
    eds_idx{t} = find(edges(:, in_out) > prop_offsetsssss(t) & edges(:, in_out) <= prop_offsetsssss(t+1));
    eds{t} = edges(eds_idx{t}, :);
end
parfor i = 1:N
    t = tlist(i);
    idx = eds{t}(:, in_out) == i;
    c{i,1} = eds_idx{t}(idx);
end

% parfor i = 1:N
%     c{i,1} = find(edges(:, in_out)==i);
% end
% c = get_node_maps(edges, in_out, N);
off = [0; cellfun(@(x) length(x), c)];
off = cumsum(off);
M  = off(end);
rv = zeros(M,1);
cv = zeros(M,1);
for i=1:N
    rv(off(i)+1: off(i+1)) = i*ones(length(c{i}),1);
    cv(off(i)+1: off(i+1)) = c{i};
end
m = sparse(rv, cv, ones(size(cv)), N, E);
end


function m = in_out(edges, in_out)
% in_out: 1->out edge, 2-> in edge
N = max(max(edges(:,1:2)));
E = size(edges, 1);
m = sparse(N, E);

rv = [];
cv = [];
c = cell(N,1);
parfor i = 1:N
    c{i,1} = find(edges(:, in_out)==i);
end
% c = get_node_maps(edges, in_out, N);
off = [0; cellfun(@(x) length(x), c)];
off = cumsum(off);
M  = off(end);
rv = zeros(M,1);
cv = zeros(M,1);
for i=1:N
    rv(off(i)+1: off(i+1)) = i*ones(length(c{i}),1);
    cv(off(i)+1: off(i+1)) = c{i};
end
m = sparse(rv, cv, ones(size(cv)), N, E);
end


function conflicts = prop_conflicts(constraints)
T = length(constraints);
x = [0 0];
for t=1:T
    x(t+1,1) = x(t,1) + size(constraints{t}, 1);
    x(t+1,2) = x(t,2) + size(constraints{t}, 2);
end

rv = [];
cv = [];
vv = [];
for t=1:T
    [r,c,v] = find(constraints{t});
    rv = [rv; r+x(t,1)];
    cv = [cv; c+x(t,2)];
    vv = [vv; v];
end
conflicts = sparse(rv, cv, vv, max(x(:,1)), max(x(:,2)));
end


function c = get_node_maps(edges, in_out, N)
c = cell(N,1);
idx = 1:size(edges,1);% edges indices
for i=1:N
    list = find(edges(:, in_out)==i);
    c{i,1} = idx(list);
    edges(list,:) = [];
    idx(list) = [];
end
end