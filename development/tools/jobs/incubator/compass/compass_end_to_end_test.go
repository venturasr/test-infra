package compass_test

import (
	"testing"

	"github.com/kyma-project/test-infra/development/tools/jobs/tester"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const compassEndToEndTestJobPath = "./../../../../../prow/jobs/incubator/compass/tests/end-to-end/end-to-end.yaml"

func TestCompassEndToEndJobReleases(t *testing.T) {
	// WHEN
	unsupportedReleases := []tester.SupportedRelease{tester.Release11, tester.Release12}

	for _, currentRelease := range tester.GetKymaReleaseBranchesBesides(unsupportedReleases) {
		t.Run(currentRelease, func(t *testing.T) {
			jobConfig, err := tester.ReadJobConfig(compassEndToEndTestJobPath)
			// THEN
			require.NoError(t, err)

			actualPre := tester.FindPresubmitJobByName(jobConfig.Presubmits["kyma-incubator/compass"], tester.GetReleaseJobName("compass-tests-end-to-end", currentRelease), currentRelease)
			require.NotNil(t, actualPre)

			assert.False(t, actualPre.SkipReport)
			assert.True(t, actualPre.Decorate)
			assert.Equal(t, "github.com/kyma-incubator/compass", actualPre.PathAlias)
			tester.AssertThatHasExtraRefTestInfra(t, actualPre.JobBase.UtilityConfig, currentRelease)
			tester.AssertThatHasPresets(t, actualPre.JobBase, tester.PresetDindEnabled, tester.PresetDockerPushRepoIncubator, tester.PresetGcrPush, tester.PresetBuildRelease)
			assert.True(t, actualPre.AlwaysRun)
			tester.AssertThatExecGolangBuildpack(t, actualPre.JobBase, tester.ImageGolangBuildpack1_11, "/home/prow/go/src/github.com/kyma-incubator/compass/tests/end-to-end")
		})
	}
}

func TestCompassEndToEndJobPresubmit(t *testing.T) {
	// WHEN
	jobConfig, err := tester.ReadJobConfig(compassEndToEndTestJobPath)
	// THEN
	require.NoError(t, err)

	actualPre := tester.FindPresubmitJobByName(jobConfig.Presubmits["kyma-incubator/compass"], "pre-master-compass-tests-end-to-end", "master")
	require.NotNil(t, actualPre)

	assert.Equal(t, 10, actualPre.MaxConcurrency)
	assert.False(t, actualPre.SkipReport)
	assert.True(t, actualPre.Decorate)
	assert.False(t, actualPre.Optional)
	assert.Equal(t, "github.com/kyma-incubator/compass", actualPre.PathAlias)
	tester.AssertThatHasExtraRefTestInfra(t, actualPre.JobBase.UtilityConfig, "master")
	tester.AssertThatHasPresets(t, actualPre.JobBase, tester.PresetDindEnabled, tester.PresetDockerPushRepoIncubator, tester.PresetGcrPush, tester.PresetBuildPr)
	assert.Equal(t, "^tests/end-to-end/", actualPre.RunIfChanged)
	tester.AssertThatJobRunIfChanged(t, *actualPre, "tests/end-to-end/some_random_file.go")
	tester.AssertThatExecGolangBuildpack(t, actualPre.JobBase, tester.ImageGolangBuildpack1_11, "/home/prow/go/src/github.com/kyma-incubator/compass/tests/end-to-end")
}

func TestCompassEndToEndJobPostsubmit(t *testing.T) {
	// WHEN
	jobConfig, err := tester.ReadJobConfig(compassEndToEndTestJobPath)
	// THEN
	require.NoError(t, err)

	actualPost := tester.FindPostsubmitJobByName(jobConfig.Postsubmits["kyma-incubator/compass"], "post-master-compass-tests-end-to-end", "master")
	require.NotNil(t, actualPost)

	assert.Equal(t, 10, actualPost.MaxConcurrency)
	assert.True(t, actualPost.Decorate)
	assert.Equal(t, "github.com/kyma-incubator/compass", actualPost.PathAlias)
	tester.AssertThatHasExtraRefTestInfra(t, actualPost.JobBase.UtilityConfig, "master")
	tester.AssertThatHasPresets(t, actualPost.JobBase, tester.PresetDindEnabled, tester.PresetDockerPushRepoIncubator, tester.PresetGcrPush, tester.PresetBuildMaster)
	assert.Equal(t, "^tests/end-to-end/", actualPost.RunIfChanged)
	tester.AssertThatJobRunIfChanged(t, *actualPost, "tests/end-to-end/some_random_file.go")
	tester.AssertThatExecGolangBuildpack(t, actualPost.JobBase, tester.ImageGolangBuildpack1_11, "/home/prow/go/src/github.com/kyma-incubator/compass/tests/end-to-end")
}
