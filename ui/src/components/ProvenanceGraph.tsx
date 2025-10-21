import * as d3 from "d3";
import type {
  SimulationNodeDatum,
  SimulationLinkDatum
} from "d3";
import { useEffect, useRef } from "react";

export interface ProvenanceGraphNode extends SimulationNodeDatum {
  id: string;
  name: string;
  relation: "ancestor" | "descendant" | "focus";
  depth: number;
}

export interface ProvenanceGraphLink extends SimulationLinkDatum<ProvenanceGraphNode> {
  source: string | ProvenanceGraphNode;
  target: string | ProvenanceGraphNode;
}

interface ProvenanceGraphProps {
  nodes: ProvenanceGraphNode[];
  links: ProvenanceGraphLink[];
  onNodeFocus?: (nodeId: string) => void;
}

export const ProvenanceGraph = ({ nodes, links, onNodeFocus }: ProvenanceGraphProps) => {
  const svgRef = useRef<SVGSVGElement | null>(null);

  useEffect(() => {
    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove();

    if (nodes.length === 0) {
      return;
    }

    const width = 640;
    const height = 420;

    svg.attr("viewBox", `0 0 ${width} ${height}`);

    const color = (node: ProvenanceGraphNode) => {
      if (node.relation === "focus") return "#2563eb";
      if (node.relation === "ancestor") return "#1d4ed8";
      return "#7c3aed";
    };

    const nodeData = nodes.map((node) => ({ ...node }));
    const linkData = links.map((link) => ({ ...link }));

    const simulation = d3
      .forceSimulation<ProvenanceGraphNode>(nodeData)
      .force(
        "link",
        d3
          .forceLink<ProvenanceGraphNode, ProvenanceGraphLink>(linkData)
          .id((d: any) => d.id)
          .distance(150)
      )
      .force("charge", d3.forceManyBody().strength(-250))
      .force("center", d3.forceCenter(width / 2, height / 2));

    const link = svg
      .append("g")
      .attr("class", "provenance-graph__links")
      .selectAll("path")
      .data(linkData)
      .enter()
      .append("path")
      .attr("class", "provenance-graph__link");

    const nodeGroup = svg
      .append("g")
      .selectAll("g")
      .data(nodeData)
      .enter()
      .append("g")
      .attr("class", (d: ProvenanceGraphNode) =>
        d.relation === "focus"
          ? "provenance-graph__node-group provenance-graph__node-group--focus"
          : "provenance-graph__node-group"
      )
      .attr("tabindex", 0)
      .attr("role", "button")
      .attr("aria-label", (d: ProvenanceGraphNode) => `Focus sample ${d.name}`)
      .on("click", (_, datum: ProvenanceGraphNode) => {
        if (datum.id) {
          onNodeFocus?.(datum.id);
        }
      })
      .on("keydown", (event: KeyboardEvent, datum: ProvenanceGraphNode) => {
        if ((event.key === "Enter" || event.key === " ") && datum.id) {
          event.preventDefault();
          onNodeFocus?.(datum.id);
        }
      });

    nodeGroup
      .append("circle")
      .attr("r", 16)
      .attr("fill", (d: ProvenanceGraphNode) => color(d))
      .attr("stroke", "#1e293b")
      .attr("stroke-width", (d: ProvenanceGraphNode) =>
        d.relation === "focus" ? 4 : 1.6
      )
      .attr("class", (d: ProvenanceGraphNode) =>
        d.relation === "focus"
          ? "provenance-graph__node provenance-graph__node--focus"
          : "provenance-graph__node"
      );

    nodeGroup
      .append("text")
      .attr("class", "provenance-graph__label")
      .attr("x", 20)
      .attr("y", 5)
      .text((d: ProvenanceGraphNode) => d.name)
      .attr("fill", "#0f172a");

    simulation.on("tick", () => {
      link.attr("d", (d: ProvenanceGraphLink) => {
        const source = d.source as ProvenanceGraphNode;
        const target = d.target as ProvenanceGraphNode;
        const sx = source.x ?? 0;
        const sy = source.y ?? 0;
        const tx = target.x ?? 0;
        const ty = target.y ?? 0;

        const dx = tx - sx;
        const dy = ty - sy;
        const dr = Math.sqrt(dx * dx + dy * dy) * 1.2;
        const sweep = 1; // clockwise

        return `M${sx},${sy} A${dr},${dr} 0 0,${sweep} ${tx},${ty}`;
      });

      nodeGroup.attr(
        "transform",
        (d: ProvenanceGraphNode) => `translate(${d.x ?? 0},${d.y ?? 0})`
      );
    });

    return () => {
      simulation.stop();
    };
  }, [nodes, links, onNodeFocus]);

  return (
    <svg
      ref={svgRef}
      className="provenance-graph__canvas"
      role="img"
      aria-label="Provenance network graph"
    />
  );
};
