<script type="ts">
  /**
   * Copyright 2021 Google LLC
   *
   * Licensed under the Apache License, Version 2.0 (the "License");
   * you may not use this file except in compliance with the License.
   * You may obtain a copy of the License at
   *
   *      http://www.apache.org/licenses/LICENSE-2.0
   *
   * Unless required by applicable law or agreed to in writing, software
   * distributed under the License is distributed on an "AS IS" BASIS,
   * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   * See the License for the specific language governing permissions and
   * limitations under the License.
   */

  import type {
    Region,
    RegionalTrends,
    TrendValue,
  } from "./data";
  import { onMount } from "svelte";
  import { params } from "./stores";
  import { 
    getRegionName,
    handleInfoPopup,
    formatDateForDisplay, 
    formatDateForStorage, 
    convertStorageDate,
    getClosestDate
  } from "./utils";

  import * as d3 from "d3";

  export let id: string;
  export let regionsByPlaceId: Map<string, Region> = new Map<string, Region>();
  export let regionalTrendsByPlaceId: Map<string, RegionalTrends>;
  export let trendLine: (trends: RegionalTrends) => TrendValue[];
  export let title: string;
  export let selectedCountryMetadata;

  let placeId: string;
  let selectedRegion: Region;
  let chartContainerElement: HTMLElement;

  const chartBounds = {
    width: 684,
    height: 276,
  };
  //https://observablehq.com/@d3/margin-convention?collection=@d3/d3-axis
  const margin = { top: 10, bottom: 30, left: 0, right: 30 };

  function getLegendComponentText(): string {
    if (selectedRegion.sub_region_3) {
      return "";
    }
    if (
      selectedRegion.sub_region_2 ||
      selectedRegion.sub_region_1_code === "US-DC"
    ) {
      return selectedCountryMetadata.subRegion3Title;
    }
    if (selectedRegion.sub_region_1) {
      return selectedCountryMetadata.subRegion2Title;
    }
    if (selectedRegion.country_region) {
      return selectedCountryMetadata.subRegion1Title;
    }
  }

  // TODO(patankar): Generalize this to allow for different selections.
  function generateChartLegend() {
    const legendContainerElement: HTMLElement =
      chartContainerElement.querySelector(".chart-legend-container");
    const legendComponentText: string = getLegendComponentText();

    d3.select(legendContainerElement).selectAll("*").remove();

    d3.select(legendContainerElement)
      .append("div")
      .attr("class", "chart-legend-rect-container")
      .append("svg")
      .append("g")
      .append("rect")
      .attr("class", `chart-legend-rect ${id}`)
      .attr("width", 16)
      .attr("height", 4);

    d3.select(legendContainerElement)
      .append("div")
      .attr("class", "chart-legend-text-container")
      .append("text")
      .attr("class", "chart-legend-text")
      .text(getRegionName(selectedRegion));

    if (legendComponentText) {
      d3.select(legendContainerElement)
        .append("div")
        .attr("class", "chart-legend-rect-container")
        .append("svg")
        .append("g")
        .append("rect")
        .attr("width", 16)
        .attr("height", 4)
        .attr("fill", "#BDC1C6");

      d3.select(legendContainerElement)
        .append("div")
        .attr("class", "chart-legend-text-container")
        .append("text")
        .attr("class", "chart-legend-text")
        .text(legendComponentText);
    }
    d3.select(legendContainerElement)
      .append("div")
      .attr("class", "chart-legend-text-container chart-axis-label")
      .append("text")
      .text("INTEREST");
  }

  function generateChartHoverCard(
    data: RegionalTrends[],
    dates: Date[],
    xScale: d3.ScaleTime<number, number, never>
  ) {
    const trendlineHoverCardMargin: number = 7;

    const chartAreaHoverElement: HTMLElement =
      chartContainerElement.querySelector(".chart-area-hover");
    const chartAreaContainerElement: HTMLElement =
      chartContainerElement.querySelector(".chart-area-container");
    const verticalLineElement: SVGGElement =
      chartContainerElement.querySelector(".chart-vertical-line");
    const hoverCardElement =
      chartContainerElement.querySelector(".chart-hover-card");
    const verticalLine = d3.select(verticalLineElement);
    const hoverCard = d3.select(hoverCardElement);

    hoverCard.selectAll("*").remove();

    const hoverCardDate = hoverCard
      .append("text")
      .attr("class", "chart-hover-card-date");

    const hoverCardTable = hoverCard
      .append("table")
      .attr("class", "chart-hover-card-table");

    // Each of the hover card rows has three entities: the icon (rectangle or "High"/"Low"), the name of the selected region, and the value for the selected region on the selected date.
    const hoverCardSelected = hoverCardTable
      .append("tr")
      .attr("id", "chart-hover-card-selected");

    const hoverCardSelectedIcon = hoverCardSelected
      .append("td")
      .append("div")
      .attr("id", "chart-hover-card-selected-icon")
      .attr("class", `chart-hover-card-selected-icon ${id}`);

    const hoverCardSelectedName = hoverCardSelected
      .append("td")
      .attr("id", "chart-hover-card-selected-name")
      .attr("class", "chart-hover-card-name");

    const hoverCardSelectedValue = hoverCardSelected
      .append("td")
      .attr("id", "chart-hover-card-selected-value")
      .attr("class", "chart-hover-card-value");

    const hoverCardHigh = hoverCardTable
      .append("tr")
      .attr("id", "chart-hover-card-high");

    const hoverCardHighIcon = hoverCardHigh
      .append("td")
      .attr("id", "chart-hover-card-high-icon")
      .attr("class", "chart-hover-card-icon-text")
      .text("High");

    const hoverCardHighName = hoverCardHigh
      .append("td")
      .attr("id", "chart-hover-card-high-name")
      .attr("class", "chart-hover-card-name");

    const hoverCardHighValue = hoverCardHigh
      .append("td")
      .attr("id", "chart-hover-card-high-value")
      .attr("class", "chart-hover-card-value");

    const hoverCardLow = hoverCardTable
      .append("tr")
      .attr("id", "chart-hover-card-low");

    const hoverCardLowIcon = hoverCardLow
      .append("td")
      .attr("id", "chart-hover-card-low-icon")
      .attr("class", "chart-hover-card-icon-text")
      .text("Low");

    const hoverCardLowName = hoverCardLow
      .append("td")
      .attr("id", "chart-hover-card-low-name")
      .attr("class", "chart-hover-card-name");

    const hoverCardLowValue = hoverCardLow
      .append("td")
      .attr("id", "chart-hover-card-low-value")
      .attr("class", "chart-hover-card-value");

    const dataByDate = new Map<string, { place_id: string; value: number }[]>();
    const selectedDataByDate = new Map<string, number>();

    data.forEach((regionalTrend) => {
      const trendValues = trendLine(regionalTrend);

      trendValues.forEach((trendValue) => {
        if (regionalTrend.place_id === selectedRegion.place_id) {
          selectedDataByDate.set(trendValue.date, trendValue.value);
        } else {
          if (dataByDate.has(trendValue.date)) {
            dataByDate.get(trendValue.date).push({
              place_id: regionalTrend.place_id,
              value: trendValue.value,
            });
          } else {
            dataByDate.set(trendValue.date, [
              { place_id: regionalTrend.place_id, value: trendValue.value },
            ]);
          }
        }
      });
    });

    const chartMouseEnter = function (d) {
      verticalLine.attr("class", "chart-vertical-line");

      hoverCard.attr("class", "chart-hover-card");
    };

    const chartMouseLeave = function (d) {
      verticalLine.attr("class", "chart-vertical-line inactive");

      hoverCard.attr("class", "chart-hover-card inactive");
    };

    const chartMouseMove = function (d) {
      dates.sort((a, b) => a.getTime() - b.getTime());
      //Calculate position relative to the SVG's viewBox
      //By default this uses the event's target which is the parent container
      //If the SVG is smaller than its defined viewBox (i.e. it was resized)
      //then the parent container offset gives us an incorrect value
      const eventX: number = d3.pointer(d, chartAreaContainerElement)[0];

      // This date might be in between provided dates.
      const hoveredDate: Date = xScale.invert(eventX);
      const hoveredDateIndex: number = d3.bisectLeft(dates, hoveredDate);
      const earlierDate: Date = dates[hoveredDateIndex - 1];
      const laterDate: Date = dates[hoveredDateIndex];
      let closestDate: Date = getClosestDate(
        hoveredDate,
        earlierDate,
        laterDate
      );
      let closestDateX: number;
      let hoverCardX: number;

      closestDateX = xScale(closestDate);

      verticalLine.attr("x1", closestDateX).attr("x2", closestDateX);

      hoverCardDate.text(formatDateForDisplay(closestDate));

      const selectedValue: number = selectedDataByDate.get(
        formatDateForStorage(closestDate)
      );

      displayRow(
        hoverCardSelected,
        hoverCardSelectedName,
        hoverCardSelectedValue,
        getRegionName(selectedRegion),
        selectedValue
      );

      if (dataByDate.size > 0) {
        const placeValues: { place_id: string; value: number }[] =
          dataByDate.get(formatDateForStorage(closestDate));
        const { min, max } = findMinAndMax(placeValues);
        const minPlaceId: string = min?.place_id;
        const minRegion: Region = regionsByPlaceId.get(minPlaceId);
        const minRegionName: string = getRegionName(minRegion);
        const minValue: number = min?.value;
        const maxPlaceId: string = max?.place_id;
        const maxRegion: Region = regionsByPlaceId.get(maxPlaceId);
        const maxRegionName: string = getRegionName(maxRegion);
        const maxValue: number = max?.value;

        displayRow(
          hoverCardHigh,
          hoverCardHighName,
          hoverCardHighValue,
          maxRegionName,
          maxValue
        );
        displayRow(
          hoverCardLow,
          hoverCardLowName,
          hoverCardLowValue,
          minRegionName,
          minValue
        );
      } else {
        hoverCardHigh.style("display", "none");
        hoverCardLow.style("display", "none");
      }

      const mediabreakpoint = 600;
      if (window.innerWidth > mediabreakpoint) {
        // Determine which side of the vertical line the hover card should be on and calculate the overall position.
        const hoverCardRect = hoverCardElement.getBoundingClientRect();
        const hoverCardWidth = hoverCardRect.width;
        const hoverCardHeight = hoverCardRect.height;
        const chartRect = chartAreaContainerElement.getBoundingClientRect();
        const chartY = chartRect.y;

        const lineRect = verticalLineElement.getBoundingClientRect();

        const isLayoutOnRight = lineRect.x < window.innerWidth / 2;

        if (isLayoutOnRight) {
          hoverCardX = lineRect.x + trendlineHoverCardMargin;
        } else {
          hoverCardX = lineRect.x - trendlineHoverCardMargin - hoverCardWidth;
        }

        hoverCard
          .style("left", `${hoverCardX}px`)
          .style(
            "top",
            `${
              chartY + window.scrollY + (chartRect.height - hoverCardHeight) / 2
            }px`
          );
      }
    };

    chartAreaHoverElement.addEventListener("mouseenter", chartMouseEnter);
    chartAreaHoverElement.addEventListener("mouseleave", chartMouseLeave);
    chartAreaHoverElement.addEventListener("mousemove", chartMouseMove);
  }

  function displayRow(
    row: d3.Selection<any, any, any, any>,
    rowName: d3.Selection<any, any, any, any>,
    rowValue: d3.Selection<any, any, any, any>,
    name: string,
    value: number
  ) {
    if (name && value !== undefined) {
      row.style("display", "table-row");
      rowName.text(name);
      rowValue.text(Math.round(value));
    } else {
      row.style("display", "none");
    }
  }

  function findMinAndMax(placeValues: { place_id: string; value: number }[]) {
    let min: { place_id: string; value: number };
    let max: { place_id: string; value: number };

    placeValues?.forEach((placeValue) => {
      if (!isNaN(placeValue.value)) {
        if (!min || placeValue.value < min.value) {
          min = placeValue;
        }

        if (!max || placeValue.value > max.value) {
          max = placeValue;
        }
      }
    });

    return { min, max };
  }

  type HtmlSelection = d3.Selection<HTMLElement, any, any, any>;
  type SvgSelection = d3.Selection<SVGGElement, any, any, any>;
  type ElementSection = HtmlSelection | SvgSelection;

  function generateChart() {
    const chartAreaContainerElement: SVGElement =
      chartContainerElement.querySelector(".chart-area-container");
    const chartAreaElement: SVGGElement =
      chartAreaContainerElement.querySelector("g");
    const xElement: SVGGElement =
      chartContainerElement.querySelector(".x.axis");
    const yElement: SVGGElement =
      chartContainerElement.querySelector(".y.axis");
    const pathsElement: SVGGElement =
      chartContainerElement.querySelector(".paths");
    const verticalLineElement: SVGGElement =
      chartContainerElement.querySelector(".chart-vertical-line");
    let chartArea: SvgSelection;
    let x: SvgSelection;
    let y: SvgSelection;
    let paths: SvgSelection;
    let verticalLine: SvgSelection;

    if (chartAreaElement) {
      chartArea = d3.select(chartAreaElement);
    } else {
      chartArea = d3
        .select(chartAreaContainerElement)
        .attr(
          "viewBox",
          [0, 0, chartBounds.width, chartBounds.height].join(" ")
        )
        .append("g");
    }

    if (xElement) {
      x = d3.select(xElement);
    } else {
      x = chartArea.append("g").attr("class", "x axis");
    }

    if (yElement) {
      y = d3.select(yElement);
    } else {
      y = chartArea.append("g").attr("class", "y axis");
    }

    if (pathsElement) {
      paths = d3.select(pathsElement);
    } else {
      paths = chartArea.append("g").attr("class", "paths");
    }

    if (verticalLineElement) {
      verticalLine = d3.select(verticalLineElement);
    } else {
      verticalLine = chartArea
        .append("g")
        .append("line")
        .attr("class", "chart-vertical-line inactive")
        .attr("y1", margin.top)
        .attr("y2", chartBounds.height - margin.bottom);
    }

    let data: RegionalTrends[] = Array.from(
      regionalTrendsByPlaceId.values()
    ).filter((t) => {
      const region = regionsByPlaceId.get(t.place_id);
      if (region) {
        let inSelectedRegion: boolean;
        const isSelectedRegion = region.place_id === selectedRegion.place_id;

        if (selectedRegion.sub_region_3) {
          // Zipcode is selected.
          return isSelectedRegion;
        }
        if (
          selectedRegion.sub_region_2 ||
          selectedRegion.sub_region_1_code === "US-DC"
        ) {
          // County is selected, want component zipcodes.
          inSelectedRegion =
            region.sub_region_2 === selectedRegion.sub_region_2 &&
            region.sub_region_1 === selectedRegion.sub_region_1;
        } else if (selectedRegion.sub_region_1) {
          // State is selected, want component counties.
          inSelectedRegion =
            !region.sub_region_3 &&
            region.sub_region_1_code === selectedRegion.sub_region_1_code;
        } else if (selectedRegion.country_region) {
          // Country is selected, want component states.
          inSelectedRegion =
            !region.sub_region_3 &&
            !region.sub_region_2 &&
            region.country_region_code === selectedRegion.country_region_code;
        }

        return inSelectedRegion || isSelectedRegion;
      } else {
        console.log("Place ID not found in regions mapping: ", t.place_id);
        return false;
      }
    });

    // A superset of dates for shown trendlines.
    // TODO(patankar): Efficiency.
    const dates: Date[] = [];
    data.forEach((regionalTrends) => {
      const regionalTrendValues = trendLine(regionalTrends);

      regionalTrendValues.forEach((regionalTrendValue) => {
        const date = convertStorageDate(regionalTrendValue.date);

        if (!dates.includes(date)) {
          dates.push(date);
        }
      });
    });

    let xScale = d3
      .scaleTime()
      .range([margin.left, chartBounds.width - margin.right])
      .domain(d3.extent(dates));
    let xAxis: d3.Axis<Date | d3.NumberValue> = d3
      .axisBottom(xScale)
      .ticks(5)
      .tickSizeOuter(0);

    let max = d3.max(
      data.flatMap((region) => trendLine(region).map((trend) => trend.value))
    );

    let yScale = d3
      .scaleLinear()
      .range([chartBounds.height - margin.bottom, margin.top])
      .domain([0, max]);
    let yAxis = d3
      .axisRight(yScale)
      .ticks(5)
      .tickSize(chartBounds.width - margin.right);

    // TODO(patankar): Define constants for styling.
    x.call(xAxis)
      .attr("transform", `translate(0,${chartBounds.height - margin.bottom})`)
      .call((g) =>
        g.select(".domain").attr("stroke-width", 1).attr("stroke", "#80868B")
      )
      .call((g) =>
        g
          .selectAll(".tick line")
          .attr("stroke-width", 1)
          .attr("stroke", "#80868B")
      )
      .call((g) =>
        g
          .selectAll(".tick text")
          .attr("color", "#5F6368")
          .attr("font-family", "Roboto")
          .attr("font-size", 12)
      );
    y.call(yAxis)
      //.attr("transform",`translate(${chartBounds.width-margin.right},0)`)
      .call((g) => g.select(".domain").remove())
      .call((g) =>
        g
          .selectAll(".tick line")
          .attr("stroke-width", 1)
          .attr("stroke", "#DADCE0")
      )
      .call((g) =>
        g
          .selectAll(".tick text")
          .attr("color", "#5F6368")
          .attr("font-family", "Roboto")
          .attr("font-size", 12)
      );
    if (chartContainerElement){
      scaleChartText();
    }
    generateChartLegend();
    generateChartHoverCard(data, dates, xScale);

    let lineFn = d3
      .line<TrendValue>()
      .defined((d) => !isNaN(d.value))
      .x((d) => xScale(new Date(d.date)))
      .y((d) => yScale(d.value))
      .curve(d3.curveLinear);

    paths
      .selectAll("path")
      .data(data, (d: RegionalTrends) => d.place_id)
      .join("path")
      .sort((a, b) => {
        if (a.place_id != selectedRegion.place_id) {
          return -1;
        }
        return 1;
      })
      .attr("id", (d) => d.place_id)
      .attr("class", (regionalTrend) => {
        if (regionalTrend.place_id === selectedRegion.place_id) {
          return `trendline trendline-selected ${id}`;
        } else {
          return "trendline";
        }
      })
      .attr("d", (d) => lineFn(trendLine(d)));
  }

  function scaleChartText() {
    // as per d3
    const padding: number = 3;
    const tickSize: number = 6;

    if (chartContainerElement){
      const chartAreaContainerElement: SVGElement =
        chartContainerElement.querySelector(".chart-area-container");
      const chartXAxisElement: SVGElement =
        chartAreaContainerElement.querySelector(".x.axis");
      const chartYAxisElement: SVGElement =
        chartAreaContainerElement.querySelector(".y.axis");
      const chartXAxisTickTextElements: NodeList =
        chartXAxisElement.querySelectorAll(".tick text");
      const chartYAxisTickTextElements: NodeList =
        chartYAxisElement.querySelectorAll(".tick text");

      const chartXAxisTickTexts: SvgSelection = d3.selectAll(
        chartXAxisTickTextElements
      );
      const chartYAxisTickTexts: SvgSelection = d3.selectAll(
        chartYAxisTickTextElements
      );

      const chartAreaScale: number =
        chartAreaContainerElement.getBoundingClientRect().width /
        chartBounds.width;
      chartXAxisTickTexts
        .attr("transform", `scale(${1 / chartAreaScale})`)
        .attr("y", `${tickSize * chartAreaScale + padding}`);
      chartYAxisTickTexts
        .attr("transform", `scale(${1 / chartAreaScale})`)
        .attr(
          "x",
          `${(chartBounds.width - margin.right) * chartAreaScale + padding}`
        );
    }
  }

  onMount(async () => {
    params.subscribe((param) => {
      placeId = param.placeId;
      if (placeId && regionsByPlaceId && regionalTrendsByPlaceId && chartContainerElement) {
        selectedRegion = regionsByPlaceId.get(placeId);

        generateChart();
      }
    });
    if (chartContainerElement){
      window.addEventListener("resize", scaleChartText);
    }
  });
</script>

<div bind:this={chartContainerElement}>
  <div class="chart-header">
    <h3>{title}</h3>
    <div
      class="info-button chart-info-button"
      on:click={(e) => {
        handleInfoPopup(e, `#info-popup-${id}`);
      }}
    >
      <span class="material-icons-outlined">info</span>
    </div>
    <div id="info-popup-{id}" class="info-popup">
      <h3 class="info-header">
        {title}
      </h3>
      <slot />
      <p>
        <a href="#about" class="info-link">Learn more</a>
      </p>
    </div>
  </div>
  <div class="chart-legend-container" />
  <div class="chart-area-hover">
    <svg class="chart-area-container" />
    <div class="chart-hover-card inactive" />
  </div>
</div>
