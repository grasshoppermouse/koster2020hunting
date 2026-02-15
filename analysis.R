library(tidyverse)
library(cchunts)
library(ggtext)

# Hunting trips. Each row is one trip
all_data <- make_joint()
societies <- read_tsv('koster_societies.tsv')

# Compute if hunting parties are mixed sex
d <- 
  all_data |> 
  left_join(societies, by = c('society'='Dataset')) |> 
  mutate(
    uniqueid = paste(society_id, forager_id),
    label = ifelse(is.na(Group), paste0('(', Country, ')'), paste0(Group, ' (', Country, ')')),
    a_1_sex = ifelse(a_1_sex == 'FALSE', 'F', a_1_sex) # Presumably miscoded
  ) |> 
  rowwise() |> 
  mutate(
    mixed = length(unique(na.omit(c_across(contains('sex'))))) > 1,
    group_size = length(na.omit(c_across(matches('a_\\d_id')))) + 1
  ) |> 
  ungroup()

# Individual hunters appear multiple times in hunting trip data
hunters <-
  d |> 
  summarise(
    n_age = length(unique(age_dist_1)),
    n_sex = length(unique(sex)),
    min_age = min(age_dist_1, na.rm = T),
    max_age = max(age_dist_1, na.rm = T),
    age_diff = max_age - min_age,
    Age = median(age_dist_1, na.rm = T), # In case this varies for some reason
    Sex = sex[1],
    .by = c(society_id, forager_id) #uniqueid
  )

# Crosstab on female_coauthorship vs female hunting
coauthor <- 
  d |> 
  group_by(society, Female_coauthorship) |>
  summarise(Female_hunting = any(sex == 'F')) |> 
  ungroup()

tbl_coauthor <- xtabs(~Female_coauthorship+Female_hunting, data=coauthor)
# out
# summary(out)

# Group sizes
# summary(d$group_size)

# Number of hunting trips with a mixed sex group
# table(d$mixed)

# Hunting parties that are not mixed sex
d_onesex <-
  d |> 
  dplyr::filter(mixed == F)

# Compute total harvest in kg across all trips, by sex
harvest_sex <- by(d_onesex$harvest, d_onesex$sex, sum)

# Hunting trips with pooled harvests
# table(d$pooled)

# Remove 13 trips with missing pooled values
# and prepare data for plotting
d_ind_pooled <- 
  d_onesex |>
  dplyr::filter(!is.na(pooled)) |> 
  mutate(
    color = ifelse(Female_coauthorship, 'red', 'black'),
    label2 = str_glue("<span code='{Code}' style='color:{color}'>{label}</span>"),
    label3 = str_glue("{Group} ({Code})"),
  ) |> 
  group_by(society) |> 
  mutate(
    mean_harvest = mean(harvest, na.rm=T)
  ) |> 
  ungroup() |> 
  mutate(
    society2 = fct_reorder(society, mean_harvest),
    label2 = fct_reorder(label2, mean_harvest),
    sex2 = ifelse(sex == 'F', 'Females', 'Males'),
    pooled = ifelse(pooled == 0, 'Individual', 'Pooled')
  )

plot_title <- str_glue('Hunting returns per trip (N = {nrow(d_ind_pooled)}) by sex and society')

plot_koster <- 
  ggplot(d_ind_pooled, aes(harvest + 1, label2)) + 
  geom_count(alpha = 0.5) + 
  scale_x_log10() +
  scale_radius(trans = 'log10') +
  labs(
    title = plot_title,
    subtitle = "Red: Studies with at least one female coauthor",
    x = 'Mass + 1 (kg)', y = ''
  ) +
  facet_grid(pooled~sex2, scales = 'free_y', space = 'free_y') +
  theme_bw(12) +
  theme(
    strip.text.y = element_text(angle=0),
    axis.text.y = element_markdown()
  )
# plot_koster
ggsave(plot = plot_koster, filename = 'plot_koster.svg', width = 12, height = 12)

d_ind <- d_ind_pooled[d_ind_pooled$pooled == "Individual",]
