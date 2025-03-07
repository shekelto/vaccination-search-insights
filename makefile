SRC_DIR = public/data

$(SRC_DIR):
	mkdir -p $@
	
US_vaccination_search_insights.csv: $(SRC_DIR)
	curl -o $(SRC_DIR)/US_vaccination_search_insights.csv https://storage.googleapis.com/covid19-open-data/covid19-vaccination-search-insights/US_vaccination_search_insights.csv

GB_vaccination_search_insights.csv: $(SRC_DIR)
	curl -o $(SRC_DIR)/GB_vaccination_search_insights.csv https://storage.googleapis.com/covid19-open-data/covid19-vaccination-search-insights/GB_vaccination_search_insights.csv

Global_l0_vaccination_search_insights.csv: US_vaccination_search_insights.csv GB_vaccination_search_insights.csv
	cat $(SRC_DIR)/$(word 1,$^) | awk 'NR==1' > $(SRC_DIR)/$@
	cat $(SRC_DIR)/$(word 1,$^) | awk -vFPAT='[^,]*|"[^"]*"' -v OFS=',' 'length($$4) < 1' >> $(SRC_DIR)/$@
	cat $(SRC_DIR)/$(word 2,$^) | awk -vFPAT='[^,]*|"[^"]*"' -v OFS=',' 'length($$4) < 1' >> $(SRC_DIR)/$@

gb_regions.csv: $(SRC_DIR)/gb_regions.csv

regions.csv: US_vaccination_search_insights.csv gb_regions.csv
	cat $(SRC_DIR)/$(word 1,$^) | awk -vFPAT='[^,]*|"[^"]*"' -v OFS=',' '{ print $$2,$$3,$$4,$$5,$$6,$$7,$$8,$$9,$$10 }' | uniq > $(SRC_DIR)/$@
	cat $(SRC_DIR)/$(word 2,$^) | awk 'NR>1' >> $(SRC_DIR)/$@

data: Global_l0_vaccination_search_insights.csv US_vaccination_search_insights.csv GB_vaccination_search_insights.csv regions.csv
