message("08: Generate every analysis table and figure in R")
o <- readRDS("data/processed/original.rds")
ex <- readRDS("data/processed/extended.rds")
spec <- readRDS("results/models/original_fits.rds")
ef <- readRDS("results/models/extension_fits.rds")
published1 <- read_csv("data/manual/published_table1.csv")

table1 <- rbindlist(lapply(seq_len(nrow(published1)), function(i) {
  z <- published1[i]
  x <- o$model[[z$variable]]
  cbind(z, n = length(x), rebuilt_mean = mean(x), rebuilt_sd = sd(x),
        rebuilt_min = min(x), rebuilt_max = max(x))
}))
table1[, matches_published_rounding :=
         mapply(function(a,b,d) round(a,d) == b, rebuilt_mean, published_mean, digits) &
         mapply(function(a,b,d) round(a,d) == b, rebuilt_sd, published_sd, digits) &
         mapply(function(a,b,d) round(a,d) == b, rebuilt_min, published_min, digits) &
         mapply(function(a,b,d) round(a,d) == b, rebuilt_max, published_max, digits)]
stopifnot(all(table1$matches_published_rounding))
write_csv(table1, "results/tables/table1_validation.csv")
format_var <- function(x, digits) mapply(function(a,d) formatC(a,format="f",digits=d),x,digits)
table1_display <- table1[, .(Variable = label,
  `Published mean` = format_var(published_mean,digits),
  `R mean` = format_var(rebuilt_mean,digits),
  `Published SD` = format_var(published_sd,digits),
  `R SD` = format_var(rebuilt_sd,digits),
  Min = format_var(rebuilt_min,digits), Max = format_var(rebuilt_max,digits))]
write_csv(table1_display, "results/tables/table1_replication.csv")
html_table(table1_display, "results/tables/table1_replication.html",
           "Table 1. Summary-statistics replication", note = "N = 21,487. All 64 displayed summary statistics match the published table at its reported precision. Podium retains the author's fractional shared-drive values.")

published2 <- read_csv("data/manual/published_table2.csv")
rebuilt2 <- read_csv("results/tables/original_full_coefficients.csv")
comparison <- merge(rebuilt2,published2,by=c("model","term"))
comparison[, `:=`(coefficient_difference = estimate - published_estimate,
                   se_difference = se - published_se)]
stopifnot(nrow(comparison) == 60L,
          max(abs(comparison$coefficient_difference)) < 2e-6,
          max(abs(comparison$se_difference)) < 2e-6)
write_csv(comparison, "results/tables/table2_full_comparison.csv")
html_table(comparison, "results/tables/table2_full_comparison.html",
           "Table 2. Full published-versus-R coefficient comparison", digits = 7,
           note = "Published benchmarks are transcribed from the supplied full Stata output for Table 2 models (1), (2), and (4). R uses binomial logit with race-clustered HC0 covariance and G/(G-1) correction. Random-intercept checks confirm a zero boundary variance.")

terms_show <- c("crace","cw","ctw","cfc","cfd","ctfc","ctfd","crace2","start")
labels <- c(crace="Prior races",cw="Own wins",ctw="Teammate wins",cfc="Own car DNF",
            cfd="Own driver DNF",ctfc="Teammate car DNF",ctfd="Teammate driver DNF",
            crace2="Prior races squared",start="Grid position")
star <- function(p) ifelse(p<.001,"***",ifelse(p<.01,"**",ifelse(p<.05,"*","")))
cell <- function(b,se,p=NA_real_,term="") {
  if (!length(b)) return("")
  if (term == "crace2") {
    scientific <- function(x) gsub("e([+-])0", "e\\1", formatC(x,format="e",digits=2))
    return(paste0(scientific(b),ifelse(is.na(p),"",star(p)),"\n(",scientific(se),")"))
  }
  dg <- if (term=="crace2") 6 else 4
  paste0(formatC(b,format="f",digits=dg), ifelse(is.na(p),"",star(p)),
         "\n(",formatC(se,format="f",digits=dg),")")
}
table2_display <- data.table(Variable=unname(labels[terms_show]))
for (m in c("M1","M2","M4")) {
  mm <- paste0("original_",m)
  for (kind in c("Published","R")) {
    col <- paste(m,kind)
    table2_display[,(col):=vapply(terms_show,function(v) {
      z<-comparison[model==mm & term==v]
      if(kind=="Published") cell(z$published_estimate,z$published_se,
                                if(nrow(z)) 2*pnorm(-abs(z$published_estimate/z$published_se)) else NA,v)
      else cell(z$estimate,z$se,z$p,v)
    },character(1))]
  }
}
wald_published <- c(M1 = 642.30, M2 = 863.91, M4 = 915.82)
stats_rows <- data.table(Variable = c("N", "Wald chi-squared"))
for (m in c("M1","M2","M4")) {
  meta <- spec$fits[[m]]$metadata
  stopifnot(abs(meta$wald_chi2 - wald_published[[m]]) < .02)
  stats_rows[, (paste(m,"Published")) := c("21,487", formatC(wald_published[[m]],format="f",digits=2))]
  stats_rows[, (paste(m,"R")) := c(format(meta$n,big.mark=","),formatC(meta$wald_chi2,format="f",digits=2))]
}
table2_display <- rbindlist(list(table2_display,stats_rows),use.names=TRUE)
write_csv(table2_display,"results/tables/table2_replication.csv")
html_table(table2_display,"results/tables/table2_replication.html",
           "Table 2. Requested model replication",note="Coefficients with race-clustered standard errors. * p&lt;.05, ** p&lt;.01, *** p&lt;.001. All models control for age, home edge, weather, track type, starters, and an intercept. M4 also includes the original 20 team indicators. Complete coefficients are in table2_full_comparison.csv.")

all_coef <- rbindlist(list(spec$fits$M4$coefficients,ef$full$coefficients,ef$modern$coefficients))
extension_terms <- setdiff(terms_show,"crace")
extension_display <- data.table(Variable=unname(labels[extension_terms]))
models <- c(`1950-2017`="original_M4",`1950-2025`="full_1950_2025_M4",`2018-2025`="modern_2018_2025_M4")
for(nm in names(models)) {
  mm <- models[[nm]]
  extension_display[,(nm):=vapply(extension_terms,function(v) {
    z<-all_coef[model==mm & term==v]
    cell(z$estimate,z$se,z$p,v)
  },character(1))]
}
write_csv(extension_display,"results/tables/table3_extension.csv")
html_table(extension_display,"results/tables/table3_extension.html",
           "Table 3. Model (4), historical and extended samples",
           note=sprintf("Race-clustered standard errors in parentheses. Same controls and frozen legacy team definitions as Table 2. Samples: %s historical rows; %s full-sample rows; %s modern estimation rows after %s perfectly predicted Williams observations are excluded. The full modern data contain %s starts in %s races. All exposure histories include the Williams observations.",
             format(nrow(o$model), big.mark=",", trim=TRUE),
             format(ef$full$metadata$n, big.mark=",", trim=TRUE),
             format(ef$modern$metadata$n, big.mark=",", trim=TRUE),
             format(ex$analysis[year>=2018, .N]-ef$modern$metadata$n, big.mark=",", trim=TRUE),
             format(ex$analysis[year>=2018, .N], big.mark=",", trim=TRUE),
             format(ex$analysis[year>=2018, uniqueN(racenr)], big.mark=",", trim=TRUE)))

rates <- ex$analysis[, .(Driver_races=.N,Races=uniqueN(racenr),Car_DNF=sum(dnfc),
  Driver_DNF=sum(dnfd),Car_DNF_rate=mean(dnfc),Driver_DNF_rate=mean(dnfd)),by=period]
rates_70_80 <- ex$analysis[year>=1970 & year<=1989,
  .(period="1970-1989",Driver_races=.N,Races=uniqueN(racenr),Car_DNF=sum(dnfc),
    Driver_DNF=sum(dnfd),Car_DNF_rate=mean(dnfc),Driver_DNF_rate=mean(dnfd))]
rates <- rbindlist(list(rates,rates_70_80),use.names=TRUE)
write_csv(rates,"results/tables/failure_rates_by_period.csv")
html_table(rates,"results/tables/failure_rates_by_period.html",
           "Failure frequency by period",digits=4,note="Rates use actual starts before modern regression-specific perfect-prediction exclusions. The 1970-1989 row is a historical subsample.")

library(ggplot2)
annual <- read_csv("results/tables/annual_failure_rates.csv")
long <- melt(annual,id.vars="year",measure.vars=c("car_failure_rate","driver_failure_rate"),
             variable.name="failure_type",value.name="rate")
long[,failure_type:=factor(failure_type,levels=c("car_failure_rate","driver_failure_rate"),
                           labels=c("Car failure","Driver failure"))]
p <- ggplot(long,aes(year,rate,color=failure_type,linetype=failure_type))+
  annotate("rect",xmin=2017.5,xmax=2025.7,ymin=-Inf,ymax=Inf,fill="#e9eef2",alpha=.75)+
  geom_line(linewidth=.8)+geom_point(data=long[year>=2018],size=1.4)+
  geom_vline(xintercept=2017.5,linetype="dashed",color="#6a7580",linewidth=.4)+
  scale_color_manual(values=c("#205a7d","#a15c35"))+
  scale_linetype_manual(values=c("solid","dashed"))+
  scale_y_continuous(labels=function(x)paste0(round(100*x),"%"),limits=c(0,NA),
                     expand=expansion(mult=c(0,.08)))+
  scale_x_continuous(breaks=c(1950,1960,1970,1980,1990,2000,2010,2018,2025))+
  labs(title="Car failures became much rarer",subtitle="Share of driver-race starts ending in each type of failure, 1950-2025",
       x=NULL,y="Failure rate",color=NULL,linetype=NULL,
       caption="1950-2017: author flags, ncs > 1 excluded. 2018-2025: Jolpica statuses plus reviewed retirement reasons.\nShading marks the extension period; data and coding change at that boundary.")+
  theme_minimal(base_size=11)+
  theme(legend.position="top",legend.justification="left",panel.grid.minor=element_blank(),
        plot.title=element_text(face="bold",color="#172c3b"),
        plot.caption=element_text(hjust=0,size=8.5),plot.margin=margin(12,16,10,10))
ggsave("results/figures/figure1_failure_rates.png",p,width=9,height=4.8,dpi=220,bg="white")
ggsave("results/figures/figure1_failure_rates.svg",p,width=9,height=4.8,bg="white",device=grDevices::svg)

forest <- all_coef[term=="cfc"]
forest[,Sample:=factor(model,levels=rev(unname(models)),labels=rev(names(models)))]
q <- ggplot(forest,aes(estimate,Sample))+
  geom_vline(xintercept=0,color="#9a9a9a",linetype="dashed")+
  geom_errorbar(aes(xmin=conf_low,xmax=conf_high),width=.12,orientation="y",color="#205a7d")+
  geom_point(size=2.5,color="#205a7d")+
  labs(title="Car-failure experience: the modern estimate is imprecise",x="Logit coefficient and 95% race-clustered confidence interval",y=NULL)+
  theme_minimal(base_size=11)+theme(panel.grid.minor=element_blank(),plot.title=element_text(face="bold",size=12))
ggsave("results/figures/figure2_car_failure_coefficients.png",q,width=8,height=3.5,dpi=220,bg="white")

# Every numeric CSV has a human-readable HTML companion, all rendered in R.
for(f in c("results/tables/car_failure_coefficient_change.csv",
           "results/tables/sensitivity_car_failure.csv","results/tables/model_samples.csv",
           "results/tables/sensitivity_failure_experience.csv",
           "results/checks/status_agreement_metrics.csv","results/checks/status_confusion_matrix.csv",
           "results/checks/cumulative_validation.csv","results/checks/random_intercept_checks.csv",
           "results/checks/coding_consistency.csv"))
  html_table(read_csv(f),sub(".csv$",".html",f),tools::file_path_sans_ext(basename(f)),digits=6)

write_session_info("results/sessionInfo.txt")
sources <- c(list.files("data/manual",full.names=TRUE),
             list.files("data/raw/jolpica",full.names=TRUE),
             list.files("data/raw/wikipedia", pattern="\\.html$", full.names=TRUE),
             file.path(author_dir,c("F1DataMainVariables.xlsx","F1StataData.dta","F1VariableDictionary.xlsx")))
manifest <- data.table(file=sources,sha256=vapply(sources,function(f)digest::digest(file=f,algo="sha256"),character(1)))
manifest[file %in% file.path(author_dir, c("F1DataMainVariables.xlsx", "F1StataData.dta",
                                         "F1VariableDictionary.xlsx")),
         file := file.path("data/raw/authors", basename(file))]
write_csv(manifest,"results/checks/input_sha256_manifest.csv")
message("Tables, figures, package versions, and input checksums written.")
