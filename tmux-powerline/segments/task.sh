# shellcheck shell=bash
# Print the tasks complated/total
  completed="$(task count status:completed)"
  total="$(task count)"
  format=" $completed/$total"

run_segment() {
	echo -n "$format"
}
