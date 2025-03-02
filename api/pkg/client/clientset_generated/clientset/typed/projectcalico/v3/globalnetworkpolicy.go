// Copyright (c) 2021 Tigera, Inc. All rights reserved.

// Code generated by client-gen. DO NOT EDIT.

package v3

import (
	"context"
	"time"

	v3 "github.com/projectcalico/api/pkg/apis/projectcalico/v3"
	scheme "github.com/projectcalico/api/pkg/client/clientset_generated/clientset/scheme"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	types "k8s.io/apimachinery/pkg/types"
	watch "k8s.io/apimachinery/pkg/watch"
	rest "k8s.io/client-go/rest"
)

// GlobalNetworkPoliciesGetter has a method to return a GlobalNetworkPolicyInterface.
// A group's client should implement this interface.
type GlobalNetworkPoliciesGetter interface {
	GlobalNetworkPolicies() GlobalNetworkPolicyInterface
}

// GlobalNetworkPolicyInterface has methods to work with GlobalNetworkPolicy resources.
type GlobalNetworkPolicyInterface interface {
	Create(ctx context.Context, globalNetworkPolicy *v3.GlobalNetworkPolicy, opts v1.CreateOptions) (*v3.GlobalNetworkPolicy, error)
	Update(ctx context.Context, globalNetworkPolicy *v3.GlobalNetworkPolicy, opts v1.UpdateOptions) (*v3.GlobalNetworkPolicy, error)
	Delete(ctx context.Context, name string, opts v1.DeleteOptions) error
	DeleteCollection(ctx context.Context, opts v1.DeleteOptions, listOpts v1.ListOptions) error
	Get(ctx context.Context, name string, opts v1.GetOptions) (*v3.GlobalNetworkPolicy, error)
	List(ctx context.Context, opts v1.ListOptions) (*v3.GlobalNetworkPolicyList, error)
	Watch(ctx context.Context, opts v1.ListOptions) (watch.Interface, error)
	Patch(ctx context.Context, name string, pt types.PatchType, data []byte, opts v1.PatchOptions, subresources ...string) (result *v3.GlobalNetworkPolicy, err error)
	GlobalNetworkPolicyExpansion
}

// globalNetworkPolicies implements GlobalNetworkPolicyInterface
type globalNetworkPolicies struct {
	client rest.Interface
}

// newGlobalNetworkPolicies returns a GlobalNetworkPolicies
func newGlobalNetworkPolicies(c *ProjectcalicoV3Client) *globalNetworkPolicies {
	return &globalNetworkPolicies{
		client: c.RESTClient(),
	}
}

// Get takes name of the globalNetworkPolicy, and returns the corresponding globalNetworkPolicy object, and an error if there is any.
func (c *globalNetworkPolicies) Get(ctx context.Context, name string, options v1.GetOptions) (result *v3.GlobalNetworkPolicy, err error) {
	result = &v3.GlobalNetworkPolicy{}
	err = c.client.Get().
		Resource("globalnetworkpolicies").
		Name(name).
		VersionedParams(&options, scheme.ParameterCodec).
		Do(ctx).
		Into(result)
	return
}

// List takes label and field selectors, and returns the list of GlobalNetworkPolicies that match those selectors.
func (c *globalNetworkPolicies) List(ctx context.Context, opts v1.ListOptions) (result *v3.GlobalNetworkPolicyList, err error) {
	var timeout time.Duration
	if opts.TimeoutSeconds != nil {
		timeout = time.Duration(*opts.TimeoutSeconds) * time.Second
	}
	result = &v3.GlobalNetworkPolicyList{}
	err = c.client.Get().
		Resource("globalnetworkpolicies").
		VersionedParams(&opts, scheme.ParameterCodec).
		Timeout(timeout).
		Do(ctx).
		Into(result)
	return
}

// Watch returns a watch.Interface that watches the requested globalNetworkPolicies.
func (c *globalNetworkPolicies) Watch(ctx context.Context, opts v1.ListOptions) (watch.Interface, error) {
	var timeout time.Duration
	if opts.TimeoutSeconds != nil {
		timeout = time.Duration(*opts.TimeoutSeconds) * time.Second
	}
	opts.Watch = true
	return c.client.Get().
		Resource("globalnetworkpolicies").
		VersionedParams(&opts, scheme.ParameterCodec).
		Timeout(timeout).
		Watch(ctx)
}

// Create takes the representation of a globalNetworkPolicy and creates it.  Returns the server's representation of the globalNetworkPolicy, and an error, if there is any.
func (c *globalNetworkPolicies) Create(ctx context.Context, globalNetworkPolicy *v3.GlobalNetworkPolicy, opts v1.CreateOptions) (result *v3.GlobalNetworkPolicy, err error) {
	result = &v3.GlobalNetworkPolicy{}
	err = c.client.Post().
		Resource("globalnetworkpolicies").
		VersionedParams(&opts, scheme.ParameterCodec).
		Body(globalNetworkPolicy).
		Do(ctx).
		Into(result)
	return
}

// Update takes the representation of a globalNetworkPolicy and updates it. Returns the server's representation of the globalNetworkPolicy, and an error, if there is any.
func (c *globalNetworkPolicies) Update(ctx context.Context, globalNetworkPolicy *v3.GlobalNetworkPolicy, opts v1.UpdateOptions) (result *v3.GlobalNetworkPolicy, err error) {
	result = &v3.GlobalNetworkPolicy{}
	err = c.client.Put().
		Resource("globalnetworkpolicies").
		Name(globalNetworkPolicy.Name).
		VersionedParams(&opts, scheme.ParameterCodec).
		Body(globalNetworkPolicy).
		Do(ctx).
		Into(result)
	return
}

// Delete takes name of the globalNetworkPolicy and deletes it. Returns an error if one occurs.
func (c *globalNetworkPolicies) Delete(ctx context.Context, name string, opts v1.DeleteOptions) error {
	return c.client.Delete().
		Resource("globalnetworkpolicies").
		Name(name).
		Body(&opts).
		Do(ctx).
		Error()
}

// DeleteCollection deletes a collection of objects.
func (c *globalNetworkPolicies) DeleteCollection(ctx context.Context, opts v1.DeleteOptions, listOpts v1.ListOptions) error {
	var timeout time.Duration
	if listOpts.TimeoutSeconds != nil {
		timeout = time.Duration(*listOpts.TimeoutSeconds) * time.Second
	}
	return c.client.Delete().
		Resource("globalnetworkpolicies").
		VersionedParams(&listOpts, scheme.ParameterCodec).
		Timeout(timeout).
		Body(&opts).
		Do(ctx).
		Error()
}

// Patch applies the patch and returns the patched globalNetworkPolicy.
func (c *globalNetworkPolicies) Patch(ctx context.Context, name string, pt types.PatchType, data []byte, opts v1.PatchOptions, subresources ...string) (result *v3.GlobalNetworkPolicy, err error) {
	result = &v3.GlobalNetworkPolicy{}
	err = c.client.Patch(pt).
		Resource("globalnetworkpolicies").
		Name(name).
		SubResource(subresources...).
		VersionedParams(&opts, scheme.ParameterCodec).
		Body(data).
		Do(ctx).
		Into(result)
	return
}
