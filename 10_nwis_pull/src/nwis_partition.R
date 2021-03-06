partition_inventory <- function(inventory, nwis_pull_size, pull_id) {
  
  # uv data count number is the number of days between the min and max observation days
  # assume that each day has 15 minute data, which is 96 obs/day
  # multiple record count by 96 to estimate record count for parsing
  inventory_name <- deparse(substitute(inventory))
  
  if (grepl('nwis_uv', inventory_name)) {
    inventory$count_nu <- inventory$count_nu*96
  } 
  
  # first, get rid of duplicate sites from whatNWISdata call
  # do not need to pull sites twice
  atomic_groups <- inventory %>%
    group_by(site_no) %>%
    slice(which.max(count_nu)) %>%
    ungroup() %>%
    arrange(desc(count_nu))
  
  target_pull_size <- nwis_pull_size
  
  n_single_site_partitions <-
    filter(atomic_groups, count_nu >= target_pull_size) %>% nrow()
  
  n_multi_site_partitions <-
    filter(atomic_groups, count_nu < target_pull_size) %>%
    pull(count_nu) %>%
    {
      ceiling(sum(.) / target_pull_size)
    }
  
  num_partitions <-
    n_single_site_partitions + n_multi_site_partitions
  
  partition_sizes <- rep(0, num_partitions)
  assignments <- rep(NA, nrow(atomic_groups)) # use a vector rather than adding a col to atomic_groups b/c it'll be way faster
  
  for (i in seq_len(nrow(atomic_groups))) {
    smallest_partition <- which.min(partition_sizes)
    assignments[i] <- smallest_partition
    size_i <- atomic_groups[[i, "count_nu"]]
    partition_sizes[smallest_partition] <- partition_sizes[smallest_partition] + size_i
  }
  
  # Prepare one data_frame containing info about each site, including
  # the pull, constituent, and task name (where task name will become the core
  # of the filename)
  pull_time <- as.Date(pull_id, '%y%m%d')

  partitions <- atomic_groups %>%
    mutate(PullDate = format(pull_time, '%Y-%m-%d'),
           PullTask = sprintf('%s_%03d', pull_id, assignments)) %>%
    select(site_no, count_nu, PullTask, PullDate)
  
  return(partitions)
  
}