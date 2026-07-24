# odin-reasoner 启动开发计划

## 目标与首个可交付闭环

建立一个独立的、资源有界的 RDF 前向推理引擎。首个可发布能力不是泛称
“支持 OWL”，而是一个有明确规则表和测试证据的 **RDFS Core materializer**：

```text
Turtle / TriG
  -> odin-rdf parser
  -> owned + interned fact store
  -> semi-naive RDFS Core closure
  -> inferred N-Triples / closure snapshot
  -> optional odin-sparql dataset.View query
```

首期以单一 triple graph 为范围。named graph、跨图语义、持久化、事务和网络
不进入 MVP。

## 必须先读的边界文档

- `../ODIN-RDF-FOUNDATION-ASSESSMENT.md`
- `../REASONER-ARCHITECTURE.md`
- `../odin-rdf/docs/architecture.md`
- `../odin-sparql/docs/dataset-api.md`（只在实现 SPARQL adapter 时）

依赖方向必须保持为：

```text
odin-reasoner --> odin-rdf
adapter/sparql --> odin-sparql
```

核心推理包绝不能导入 `odin-sparql`；SPARQL adapter 必须是可选的单独包。长期
持有 parser sink 给出的 term 时，必须立即 clone 或 intern。blank node identity
必须始终包含 `(Blank_Node_Scope, label)`。

## 不做的事项

- 不把 graph store、推理或规则执行放进 `odin-rdf`。
- 不复制或改造 `odin-sparql` 的 `Memory_Dataset`：它是 sealed、线性扫描的
  查询正确性基线，不是增量事实库。
- 不先抽取 `odin-graph` / `odin-store` 公共仓库。
- 不实现 SPARQL Update、SPARQL Protocol、HTTP、持久化或事务。
- 不声称 OWL 2 DL、OWL Full、完整 RDFS 或 RIF-PRD 支持。
- 不让推理引擎通过完整 SPARQL evaluator 匹配规则体。

## 工作原则

1. 每一项语义能力都先有明确 profile、规则表、资源限制和独立测试 gate。
2. RDF fact 是集合；规则匹配的中间 binding 不是 SPARQL multiset。
3. 任何上限触发都必须返回显式错误，不能静默截断 closure。
4. 所有公开返回值都要写明 owner、借用期和 destroy 责任。
5. 每个 milestone 通过后再扩展范围；不要先搭“通用本体平台”。

## Phase 0 — 仓库契约与可编译骨架

### 交付物

- `README.md`：定位、非目标、依赖方向、RDFS Core profile 状态。
- `ROADMAP.md`：下列 milestone 与完成定义。
- `reasoner/` 根包及最小 smoke test。
- `docs/architecture.md`：term ownership、fact identity、资源上限、错误模型。
- Odin named collection 依赖 `odin-rdf:rdf`；不允许机器绝对路径 import。

### 决策（直接采用）

- 首期输入是 application-owned `rdf.Triple` sink；Turtle 示例仅是 ingestion
  adapter，不成为核心依赖。
- 首期输出可迭代为 owned `rdf.Triple`，并提供 N-Triples 示例程序。
- API 在 `0.x` 阶段保持 experimental；先避免冻结内部 store 形状。
- 限制项至少包含：`Max_Terms`、`Max_Facts`、`Max_Derivations`、`Max_Rounds`。

### 验收

```sh
odin check reasoner -no-entry-point -collection:odin-rdf=../odin-rdf
odin test reasoner -collection:odin-rdf=../odin-rdf
```

## Phase 1 — owned term dictionary 与增量 fact store

### 实现顺序

1. `reasoner/term`
   - 定义不暴露底层布局的 `Term_ID`。
   - intern `rdf.Term`，复制 lexical strings，并能由 `Term_ID` 取回借用的 term。
   - 区分 IRI、literal、language、datatype、blank-node scope 与 label。
2. `reasoner/store`
   - `Fact { subject, predicate, object: Term_ID }`。
   - `insert` 返回 `added`；相同事实只能保存一次。
   - `contains`、owned fact iteration、asserted / inferred origin 标记。
   - 按给定常量约束执行 match；先实现并 benchmark 适当的 SPO / POS / OSP
     索引组合，避免所有规则都退化为全表扫描。
3. `reasoner/import`
   - 提供 RDF parser sink，逐条 intern/insert，绝不保留 callback 借用值。

### 必测不变量

- 相同 triple 第二次插入是成功 no-op。
- 两份文档同 label 的 blank node 不会合并；同 scope 同 label 会合并。
- term / fact / lexical budget 满时 state 不被部分破坏。
- 所有 subject/predicate/object 常量组合和全 wildcard pattern 都返回正确集合。
- asserted 与 inferred 的同一事实去重规则有文档和测试。

### 验收

- 用 Turtle sink 导入至少一个含 blank node 的 fixture，输出一致的 owned facts。
- ASan 或等价内存检查覆盖 dictionary、store 和 sink lifetime。
- 记录基础 scan 基准；先记录，不以性能数字作为 API 设计前提。

## Phase 2 — 最小规则 IR 与 semi-naive 引擎

### 规则引擎范围

实现足以表达 RDFS Core 的最小 rule IR，而不是先解析 RIF：

- variables、constant terms、triple body atoms、conjunctive body、一个或多个
  triple head templates；
- binding compatibility / unification；
- agenda 或 delta facts；
- semi-naive evaluation：每轮至少一个 body atom 由 delta 驱动；
- 达到 fixpoint、`Max_Rounds` 或 `Max_Derivations` 时有确定结果；
- 产生 inferred fact 时记录 `rule_id` 和首个支持事实集合的 ID。

### 必测不变量

- 递归规则闭包终止，重复导出不会生成新事实。
- 基线 naive evaluator（仅测试中）与 semi-naive evaluator 在小图上闭包相同。
- 多个推导路径生成同一事实时，fact 仍只出现一次。
- 每个资源限制都可被 fixture 精准触发，且没有 partial-success 结果。

## Phase 3 — RDFS Core profile

先把 profile 写进 `reasoner/rdfs/profile.md`，并为每条规则分配稳定 ID。MVP
规则固定为：

| ID | 前提 | 结论 |
| --- | --- | --- |
| RDFS-SC | `C1 rdfs:subClassOf C2`, `x rdf:type C1` | `x rdf:type C2` |
| RDFS-SC-TRANS | `C1 rdfs:subClassOf C2`, `C2 rdfs:subClassOf C3` | `C1 rdfs:subClassOf C3` |
| RDFS-SP | `P1 rdfs:subPropertyOf P2`, `s P1 o` | `s P2 o` |
| RDFS-SP-TRANS | `P1 rdfs:subPropertyOf P2`, `P2 rdfs:subPropertyOf P3` | `P1 rdfs:subPropertyOf P3` |
| RDFS-DOMAIN | `P rdfs:domain C`, `s P o` | `s rdf:type C` |
| RDFS-RANGE | `P rdfs:range C`, `s P o` | `o rdf:type C` |

不要在首版无意加入 RDFS axiomatic triples、容器词汇规则、datatype entailment 或
无限词汇闭包；这些必须先作为 profile 的独立扩展设计。

### 测试与声明

- 每条规则：单规则、组合、递归、cycle、重复事实、blank node、literal object
  fixtures。
- 针对实际 profile 固定 W3C RDF Semantics entailment vectors；无法适配的向量
  必须在 conformance ledger 中说明原因。
- profile README 仅声称通过的 rule table 和 fixture 数，不笼统声明“RDFS 支持”。

### 首个演示程序

`examples/rdfs_materialize/main.odin`：读取本地 Turtle，materialize，分开输出
asserted 与 inferred 的 N-Triples，并展示一条 provenance 记录。

## Phase 4 — SPARQL closure adapter

在 `adapter/sparql`（或独立 integration package）实现 read-only snapshot adapter：

- 只依赖公开的 `sparql/dataset.View` / `custom_view` 边界；
- 把 closure 作为固定 snapshot 提供，正确实现 Default / Named / Any_Named graph
  mode；首期若只支持 default graph，要在创建 adapter 时明确拒绝其他 graph mode；
- 尊重 scan sink 的 `false` early-stop，不把它转为错误；
- adapter 不参与推理，也不允许推理期间暴露可变 store。

端到端 gate：`Turtle -> materialize RDFS Core -> SPARQL SELECT/ASK/CONSTRUCT`。
至少覆盖 subclass、subproperty、domain/range、closure dedupe 和结果 owner 在 store
销毁前后的边界。

## Phase 5 — 后续路线（不提前实现）

1. OWL 2 RL：按规则簇逐步编译到 Phase 2 rule IR；每个簇有 profile、限制和测试。
2. provenance / explanation：从“首条支持”扩展到可控大小的 derivation DAG 与查询 API。
3. RIF Core，之后再评估 RIF-BLD；RIF-PRD 另立执行模型评估。
4. 只有 SPARQL 与 reasoner 都真实复用同一套 term dictionary、index 和 snapshot
   机制后，才评估抽取 `odin-graph` / `odin-store`。

SHACL 属于数据验证而非这个推理 MVP；有明确验证产品需求时再单独立项。

## 新 Codex 窗口的首条执行指令

> 在 `odin-reasoner` 中执行本计划的 Phase 0 和 Phase 1。先完整阅读相邻目录的
> `ODIN-RDF-FOUNDATION-ASSESSMENT.md`、`REASONER-ARCHITECTURE.md` 与
> `odin-rdf/docs/architecture.md`。保持 reasoner 核心只依赖 `odin-rdf`；不要创建
> `odin-graph`，不要接入 `odin-sparql`，不要实现规则引擎。实现可编译的仓库骨架、
> owned term dictionary、增量 triple fact store、RDF parser sink import、显式资源
> 上限，以及本计划列出的 Phase 1 不变量测试。完成后运行对应 check/test，并汇报
> API、限制、测试结果与尚未实现的 Phase 2 边界。
